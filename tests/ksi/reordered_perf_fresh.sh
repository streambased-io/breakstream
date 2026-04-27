#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE_DIR=$( cd -- "$SCRIPT_DIR/../../" &> /dev/null && pwd )
ENV_DIR="$BASE_DIR/environment"
CONFIG_PATH="$ENV_DIR/ksi-reordered-groups.yaml"

cat > "$CONFIG_PATH" <<EOF
reorderedGroups:
  - groupId: "reordered-e2e-performance"
    clientId: "consumer-reordered-e2e-performance"
    sourceTopic: "reordered_perf_customers"
    filter: "Name = 'Reordered Perf Match'"
    orderBy: "kafka_timestamp ASC"
EOF

echo "Using reordered performance group: reordered-e2e-performance"
echo "Performance target records: ${REORDERED_PERF_TARGET_RECORDS:-1000000}"

cd "$ENV_DIR"
docker --log-level ERROR compose up -d --force-recreate ksi

"$SCRIPT_DIR/reordered_perf_run.sh"
