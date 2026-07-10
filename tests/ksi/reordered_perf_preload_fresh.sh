#!/bin/bash
# Recreates KSI (with preload: record cache + prefetch) and reruns the reordered perf
# consumers against already-loaded data.
# Usage: reordered_perf_preload_fresh.sh [coldset|isk-hot]  (default: coldset)

set -euo pipefail

MODE="${1:-coldset}"

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

BASELINE_LABEL="ksi-preload-baseline"
ORDERED_LABEL="ksi-preload-ordered"
POLL_TIMEOUT_ENV=()
BATCH_SIZE_DEFAULT=10000
COMPOSE_FILE_LIST="docker-compose.yaml:docker-compose.preload.yaml"

if [ "$MODE" = "isk-hot" ]
then
  BATCH_SIZE_DEFAULT=50000
  COMPOSE_FILE_LIST="docker-compose.yaml:docker-compose.isk-hot.yaml:docker-compose.preload.yaml"
  echo "Using ISK hotset preload reordered performance groups:"
  echo "  baseline: reordered-e2e-performance -> reordered_perf_customers"
  echo "  ordered:  reordered-e2e-performance-ordered -> reordered_perf_customers_ordered"
  echo "  catalog:  KSI_SPARK_CATALOG_NAME=isk"
  echo "  namespace: KSI_ICEBERG_NAMESPACE=hotset"
  echo "  read timeout: KSI_COLD_STORAGE_TIMEOUT_MS=${KSI_COLD_STORAGE_TIMEOUT_MS:-120000}"
  BASELINE_LABEL="ksi-hotset-preload-baseline"
  ORDERED_LABEL="ksi-hotset-preload-ordered"
  POLL_TIMEOUT_ENV=("REORDERED_PERF_POLL_TIMEOUT_SECONDS=${REORDERED_PERF_POLL_TIMEOUT_SECONDS:-120}")
else
  echo "Using preload reordered performance groups:"
  echo "  baseline: reordered-e2e-performance -> reordered_perf_customers"
  echo "  ordered:  reordered-e2e-performance-ordered -> reordered_perf_customers_ordered"
fi

echo "  record cache: KSI_RECORD_CACHE_ENABLED=${KSI_RECORD_CACHE_ENABLED:-true}"
echo "  prefetch:     KSI_PREFETCH_ENABLED=${KSI_PREFETCH_ENABLED:-true}"
echo "  cache bytes:  KSI_RECORD_CACHE_MAX_BYTES=${KSI_RECORD_CACHE_MAX_BYTES:-536870912}"
echo "  batches:      KSI_PREFETCH_BATCH_COUNT=${KSI_PREFETCH_BATCH_COUNT:-5}"
echo "  batch size:   KSI_BATCH_SIZE=${KSI_BATCH_SIZE:-$BATCH_SIZE_DEFAULT}"
echo "  threshold:    KSI_PREFETCH_TRIGGER_THRESHOLD=${KSI_PREFETCH_TRIGGER_THRESHOLD:-2}"
echo "  compose file: $COMPOSE_FILE_LIST"
echo "Performance target records: ${REORDERED_PERF_TARGET_RECORDS:-1000000}"

cd "$ENV_DIR"
export COMPOSE_FILE="$COMPOSE_FILE_LIST"
docker --log-level ERROR compose up -d --force-recreate ksi

env "${POLL_TIMEOUT_ENV[@]}" \
  REORDERED_PERF_BASELINE_LABEL="$BASELINE_LABEL" \
  REORDERED_PERF_ORDERED_LABEL="$ORDERED_LABEL" \
  "$SCRIPT_DIR/reordered_perf_run.sh"
