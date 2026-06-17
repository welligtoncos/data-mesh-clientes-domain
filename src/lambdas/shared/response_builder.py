import json
from typing import Any

DEFAULT_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}


def success(body: Any, status_code: int = 200) -> dict:
    return {
        "statusCode": status_code,
        "headers": DEFAULT_HEADERS,
        "body": json.dumps(body, default=str),
    }


def error(message: str, status_code: int = 400, details: dict | None = None) -> dict:
    payload = {"error": message}
    if details:
        payload["details"] = details
    return {
        "statusCode": status_code,
        "headers": DEFAULT_HEADERS,
        "body": json.dumps(payload),
    }
