#! /bin/sh
# Source this file to get roll_topics(). POSIX sh, so the union-roll compose service sources it too.
# Rolls each topic's sealed hot epochs into direct.coldset.<topic> through Hyperstream's POST /api/union/roll
# and returns non-zero when any roll failed. A topic with no new rows answers committed=false, which is a success; a failed roll prints Hyperstream's error body to stderr.
# HYPERSTREAM_URL and HYPERSTREAM_CREDS (api key:secret) default to the host-side compose ports.

roll_topics() {
  roll_status=0
  for roll_topic in "$@"
  do
    roll_body=$(curl --fail-with-body -sS --max-time 600 -u "${HYPERSTREAM_CREDS:-sbpk_12345678:sbsk_12345678}" \
      -H 'content-type: application/json' -d "{\"table\":\"$roll_topic\"}" \
      "${HYPERSTREAM_URL:-http://localhost:9088}/api/union/roll") \
      && echo "$roll_body" || { echo "roll $roll_topic failed: $roll_body" >&2; roll_status=1; }
  done
  return $roll_status
}
