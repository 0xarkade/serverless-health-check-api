"""Health check endpoint: logs the request, stores it in DynamoDB, returns 200."""

from __future__ import annotations

import json
import logging
import os
import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Optional

import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

# Built once per execution environment rather than per invocation, so a warm
# container pays for credential resolution and TLS setup only on cold start.
# A missing TABLE_NAME fails here, at init, instead of on the first request.
_TABLE = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


class ValidationError(Exception):
    pass


def _extract_payload(event: dict, method: str) -> Optional[Any]:
    # GET carries no body, so it is treated as a liveness probe.
    if method == "GET":
        return None

    body = event.get("body")
    if not body or not body.strip():
        raise ValidationError(
            "Request body is required and must be a JSON object "
            "containing a 'payload' key."
        )

    try:
        # DynamoDB rejects floats, so parse them straight to Decimal.
        parsed = json.loads(body, parse_float=Decimal)
    except json.JSONDecodeError as exc:
        raise ValidationError("Request body must be valid JSON.") from exc

    if not isinstance(parsed, dict):
        raise ValidationError("Request body must be a JSON object.")
    if "payload" not in parsed:
        raise ValidationError("Request body is missing the required 'payload' key.")

    return parsed["payload"]


def _build_item(event: dict, method: str, payload: Optional[Any], context: Any) -> dict:
    ctx = event.get("requestContext") or {}
    identity = ctx.get("identity") or {}

    item = {
        "id": str(uuid.uuid4()),
        "received_at": datetime.now(timezone.utc).isoformat(),
        "environment": os.environ.get("ENVIRONMENT", "unknown"),
        "http_method": method,
        "path": event.get("path"),
        "source_ip": identity.get("sourceIp"),
        "user_agent": identity.get("userAgent"),
        "api_request_id": ctx.get("requestId"),
        "lambda_request_id": getattr(context, "aws_request_id", None),
    }
    if payload is not None:
        item["payload"] = payload

    return {k: v for k, v in item.items() if v is not None}


def _response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def lambda_handler(event: dict, context: Any) -> dict:
    logger.info(json.dumps({"message": "Received request", "event": event}, default=str))

    method = str(event.get("httpMethod", "")).upper()

    try:
        payload = _extract_payload(event, method)
    except ValidationError as exc:
        logger.warning(json.dumps({"message": "Request rejected", "reason": str(exc)}))
        return _response(400, {"status": "error", "message": str(exc)})

    item = _build_item(event, method, payload, context)

    try:
        _TABLE.put_item(Item=item)
    except Exception:
        # Full traceback for operators, generic message for the caller.
        logger.exception("Failed to write request to DynamoDB")
        return _response(500, {"status": "error", "message": "Internal server error."})

    logger.info(json.dumps({"message": "Request stored", "id": item["id"]}))
    return _response(200, {"status": "healthy", "message": "Request processed and saved."})
