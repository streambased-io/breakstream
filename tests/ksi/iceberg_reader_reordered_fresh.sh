#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE_DIR=$( cd -- "$SCRIPT_DIR/../../" &> /dev/null && pwd )
ENV_DIR="$BASE_DIR/environment"
CONFIG_PATH="$ENV_DIR/ksi-reordered-groups.yaml"

REORDERED_FIRST_GROUP="reordered-e2e-first-consume"
REORDERED_RESUME_GROUP="reordered-e2e-resume"
REORDERED_FIRST_CLIENT="consumer-reordered-e2e-first-consume"
REORDERED_RESUME_CLIENT="consumer-reordered-e2e-resume"

cat > "$CONFIG_PATH" <<EOF
reorderedGroups:
  - groupId: "$REORDERED_FIRST_GROUP"
    clientId: "$REORDERED_FIRST_CLIENT"
    sourceTopic: "reordered_customers"
    filter: "Name = 'Reordered Match'"
    orderBy: "kafka_timestamp ASC"
  - groupId: "$REORDERED_RESUME_GROUP"
    clientId: "$REORDERED_RESUME_CLIENT"
    sourceTopic: "reordered_customers"
    filter: "Name = 'Reordered Match'"
    orderBy: "kafka_timestamp ASC"
EOF

echo "Using Spark-only reordered groups:"
echo "  first consume: $REORDERED_FIRST_GROUP"
echo "  resume:        $REORDERED_RESUME_GROUP"
echo "  catalog:       KSI_SPARK_CATALOG_NAME=isk"
echo "  namespace:     KSI_ICEBERG_NAMESPACE=merged"
echo "  expected:      6 reordered matches across coldset and hotset"

cd "$ENV_DIR"
docker --log-level ERROR compose up -d --force-recreate ksi

REORDERED_FIRST_GROUP="$REORDERED_FIRST_GROUP" \
REORDERED_RESUME_GROUP="$REORDERED_RESUME_GROUP" \
REORDERED_EXPECTED_MATCH_RECORDS="${REORDERED_EXPECTED_MATCH_RECORDS:-6}" \
REORDERED_POLL_TIMEOUT_SECONDS="${REORDERED_POLL_TIMEOUT_SECONDS:-120}" \
"$SCRIPT_DIR/reordered_run.sh"
