#! /bin/bash
# AC15: Hyperstream's Spark Connect client (4.1.0) runs a trivial statement through its
# existing query path against this stack's Spark server. Failure is a blocker for the demo step.

HYPERSTREAM_URL=${HYPERSTREAM_URL:-http://localhost:9088}
CREDS=${CREDS:-sbpk_12345678:sbsk_12345678}

RESPONSE=$(curl -sS --max-time 120 -u "$CREDS" -H 'content-type: application/json' \
  -d '{"sql":"SELECT count(*) FROM customers","index":false,"set":"UNIFIED"}' "$HYPERSTREAM_URL/api/query" -w '\n%{http_code}')
STATUS=$(echo "$RESPONSE" | tail -n 1)
if [ "$STATUS" != "200" ]
then
  echo "BLOCKER: Spark Connect pairing check failed, HTTP $STATUS"
  echo "$RESPONSE" | head -n 5
  exit 1
fi
echo "Spark Connect pairing check passed"
