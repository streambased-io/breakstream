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
    orderBy: "kafka_timestamp ASC"
  - groupId: "reordered-e2e-performance-ordered"
    clientId: "consumer-reordered-e2e-performance-ordered"
    sourceTopic: "reordered_perf_customers_ordered"
    orderBy: "kafka_timestamp ASC"
EOF

echo "Using ISK hotset reordered performance groups:"
echo "  baseline: reordered-e2e-performance -> reordered_perf_customers"
echo "  ordered:  reordered-e2e-performance-ordered -> reordered_perf_customers_ordered"
echo "  catalog:  KSI_SPARK_CATALOG_NAME=isk"
echo "  namespace: KSI_ICEBERG_NAMESPACE=hotset"
echo "  batch size: KSI_BATCH_SIZE=${KSI_BATCH_SIZE:-50000}"
echo "  read timeout: KSI_COLD_STORAGE_TIMEOUT_MS=120000"
echo "Performance target records: ${REORDERED_PERF_TARGET_RECORDS:-1000000}"

cd "$ENV_DIR"
KSI_BATCH_SIZE="${KSI_BATCH_SIZE:-50000}" \
KSI_COLD_STORAGE_TIMEOUT_MS=120000 \
KSI_SPARK_CATALOG_NAME=isk \
KSI_ICEBERG_NAMESPACE=hotset \
docker --log-level ERROR compose up -d --force-recreate ksi

REORDERED_PERF_BASELINE_LABEL="ksi-hotset-baseline" \
REORDERED_PERF_ORDERED_LABEL="ksi-hotset-ordered" \
REORDERED_PERF_POLL_TIMEOUT_SECONDS="${REORDERED_PERF_POLL_TIMEOUT_SECONDS:-120}" \
"$SCRIPT_DIR/reordered_perf_run.sh"
