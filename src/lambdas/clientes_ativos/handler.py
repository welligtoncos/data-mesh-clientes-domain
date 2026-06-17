import logging
import os
import re

from shared.athena_client import AthenaQueryError, run_query
from shared.response_builder import error, success

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = os.environ.get("TABLE_NAME", "clientes_ativos_v1")
VALID_STATES = {
    "AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO", "MA", "MG", "MS", "MT",
    "PA", "PB", "PE", "PI", "PR", "RJ", "RN", "RO", "RR", "RS", "SC", "SE", "SP", "TO",
}
STATE_PATTERN = re.compile(r"^[A-Z]{2}$")


def _parse_estado(event: dict) -> tuple[str | None, dict | None]:
    params = event.get("queryStringParameters") or {}
    estado = params.get("estado")
    if estado is None:
        return None, None
    estado = estado.strip().upper()
    if not STATE_PATTERN.match(estado) or estado not in VALID_STATES:
        return None, error(
            "Invalid query parameter 'estado'. Use a valid Brazilian state code (e.g. SP).",
            status_code=400,
            details={"estado": params.get("estado")},
        )
    return estado, None


def handler(event, context):
    try:
        logger.info("event=%s", event)
        estado, validation_error = _parse_estado(event)
        if validation_error:
            return validation_error

        where_clause = f"WHERE customer_state = '{estado}'" if estado else ""
        query = f"""
            SELECT
                customer_id,
                customer_unique_id,
                customer_state,
                CAST(ultima_compra AS VARCHAR) AS ultima_compra,
                CAST(dias_desde_ultima_compra AS VARCHAR) AS dias_desde_ultima_compra,
                CAST(ativo AS VARCHAR) AS ativo
            FROM {TABLE_NAME}
            {where_clause}
            ORDER BY ultima_compra DESC
            LIMIT 1000
        """
        rows = run_query(query)
        payload = [
            {
                "customer_id": row["customer_id"],
                "customer_unique_id": row.get("customer_unique_id"),
                "customer_state": row["customer_state"],
                "ultima_compra": row["ultima_compra"],
                "dias_desde_ultima_compra": int(row["dias_desde_ultima_compra"]),
                "ativo": row["ativo"].lower() == "true",
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
