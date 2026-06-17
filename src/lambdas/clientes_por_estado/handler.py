import logging
import os

from shared.athena_client import AthenaQueryError, run_query
from shared.response_builder import error, success

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = os.environ.get("TABLE_NAME", "clientes_por_estado_v1")


def handler(event, context):
    try:
        logger.info("event=%s", event)
        query = f"""
            SELECT
                customer_state,
                CAST(total_clientes AS VARCHAR) AS total_clientes,
                CAST(data_referencia AS VARCHAR) AS data_referencia
            FROM {TABLE_NAME}
            ORDER BY total_clientes DESC
        """
        rows = run_query(query)
        payload = [
            {
                "customer_state": row["customer_state"],
                "total_clientes": int(row["total_clientes"]),
                "data_referencia": row.get("data_referencia"),
            }
            for row in rows
        ]
        return success(payload)
    except AthenaQueryError as exc:
        logger.exception("Athena failure")
        return error(str(exc), status_code=500)
    except Exception as exc:
        logger.exception("Unhandled failure")
        return error("Internal server error", status_code=500, details={"reason": str(exc)})
