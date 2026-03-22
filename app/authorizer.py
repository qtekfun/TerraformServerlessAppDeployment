"""
Lambda REQUEST authorizer for API Gateway v2 (HTTP API).

Validates the x-api-key header against the API_KEY environment variable.
Returns a simple response understood by API Gateway v2's simple response format.

To call a protected endpoint:
    curl -X POST -H "x-api-key: <your-key>" -H "Content-Type: application/json" \
         -d '{"parameter": "hello world"}' <api_url>
"""

import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

_API_KEY = os.environ.get("API_KEY", "")


def handler(event, context):
    headers = event.get("headers") or {}
    provided_key = headers.get("x-api-key", "")

    authorized = bool(_API_KEY) and provided_key == _API_KEY
    logger.info("Authorization result: %s", authorized)

    return {"isAuthorized": authorized}
