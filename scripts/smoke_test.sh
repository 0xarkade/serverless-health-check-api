#!/usr/bin/env bash
# Verifies a deployed health check endpoint end to end.
# Usage: smoke_test.sh <health-url> <api-key>
set -euo pipefail

URL="${1:?usage: smoke_test.sh <health-url> <api-key>}"
KEY="${2:?usage: smoke_test.sh <health-url> <api-key>}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

echo "1/4 request without an api key is rejected"
code=$(curl -sS -o /dev/null -w '%{http_code}' "$URL")
[ "$code" = "403" ] || fail "expected 403 without a key, got $code"

echo "2/4 GET with a key reports healthy"
body=$(curl -sS -H "x-api-key: $KEY" "$URL")
echo "$body" | grep -q '"status": *"healthy"' || fail "expected healthy, got: $body"

echo "3/4 POST with a payload is accepted"
code=$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
  -H "x-api-key: $KEY" -H 'Content-Type: application/json' \
  -d '{"payload":{"source":"smoke-test"}}' "$URL")
[ "$code" = "200" ] || fail "expected 200 for a valid post, got $code"

echo "4/4 POST without a payload is rejected at the gateway"
code=$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
  -H "x-api-key: $KEY" -H 'Content-Type: application/json' \
  -d '{"nope":1}' "$URL")
[ "$code" = "400" ] || fail "expected 400 for a body with no payload, got $code"

echo "all smoke tests passed"
