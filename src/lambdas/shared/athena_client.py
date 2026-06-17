import os
import time
from typing import Any

import boto3

POLL_INTERVAL_SECONDS = 0.5
MAX_WAIT_SECONDS = 28


class AthenaQueryError(Exception):
    def __init__(self, message: str, query_execution_id: str | None = None):
        super().__init__(message)
        self.query_execution_id = query_execution_id


def _get_client():
    return boto3.client("athena")


def run_query(query: str) -> list[dict[str, Any]]:
    workgroup = os.environ["ATHENA_WORKGROUP"]
    database = os.environ["GLUE_DATABASE"]

    client = _get_client()
    execution = client.start_query_execution(
        QueryString=query,
        QueryExecutionContext={"Database": database},
        WorkGroup=workgroup,
    )
    query_execution_id = execution["QueryExecutionId"]

    elapsed = 0.0
    while elapsed < MAX_WAIT_SECONDS:
        result = client.get_query_execution(QueryExecutionId=query_execution_id)
        state = result["QueryExecution"]["Status"]["State"]
        if state == "SUCCEEDED":
            return _fetch_rows(client, query_execution_id)
        if state in {"FAILED", "CANCELLED"}:
            reason = result["QueryExecution"]["Status"].get("StateChangeReason", state)
            raise AthenaQueryError(f"Athena query {state}: {reason}", query_execution_id)
        time.sleep(POLL_INTERVAL_SECONDS)
        elapsed += POLL_INTERVAL_SECONDS

    client.stop_query_execution(QueryExecutionId=query_execution_id)
    raise AthenaQueryError("Athena query timed out", query_execution_id)


def _fetch_rows(client, query_execution_id: str) -> list[dict[str, Any]]:
    paginator = client.get_paginator("get_query_results")
    rows: list[dict[str, Any]] = []
    headers: list[str] = []

    for page in paginator.paginate(QueryExecutionId=query_execution_id):
        for index, row in enumerate(page["ResultSet"]["Rows"]):
            values = [column.get("VarCharValue") for column in row["Data"]]
            if index == 0 and not headers:
                headers = values
                continue
            rows.append(dict(zip(headers, values)))

    return rows
