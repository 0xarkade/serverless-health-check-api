#!/usr/bin/env bash
# Verifies a deployed health check endpoint end to end.
# Usage: smoke_test.sh <health-url> <api-key>
set -euo pipefail

URL="${1:?usage: smoke_test.sh <health-url> <api-key>}"
KEY="${2:?usage: smoke_test.sh <health-url> <api-key>}"

ATTEMPTS=6
DELAY=10

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

echo "1/4 request without an api key is rejected"
code=$(curl -sS -o /dev/null -w '%{http_code}' "$URL")
[ "$code" = "403" ] || fail "expected 403 without a key, got $code"

# On a freshly created stage the api key and its usage plan association take a
# few seconds to become effective, so the first authenticated call is retried
# rather than treated as a failure. Later checks need no retry because by then
# the key is known to work.
echo "2/4 GET with a key reports healthy"
for attempt in $(seq 1 "$ATTEMPTS"); do
  body=$(curl -sS -H "x-api-key: $KEY" "$URL")
  if echo "$body" | grep -q '"status": *"healthy"'; then
    break
  fi
  if [ "$attempt" -eq "$ATTEMPTS" ]; then
    fail "expected healthy after ${ATTEMPTS} attempts, last response: $body"
  fi
  echo "    key not effective yet, retrying in ${DELAY}s (attempt ${attempt}/${ATTEMPTS})"
  sleep "$DELAY"
done

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
