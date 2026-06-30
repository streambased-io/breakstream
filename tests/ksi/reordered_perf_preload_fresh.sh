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

echo "Using preload reordered performance groups:"
echo "  baseline: reordered-e2e-performance -> reordered_perf_customers"
echo "  ordered:  reordered-e2e-performance-ordered -> reordered_perf_customers_ordered"
echo "  record cache: KSI_RECORD_CACHE_ENABLED=${KSI_RECORD_CACHE_ENABLED:-true}"
echo "  prefetch:     KSI_PREFETCH_ENABLED=${KSI_PREFETCH_ENABLED:-true}"
echo "  cache bytes:  KSI_RECORD_CACHE_MAX_BYTES=${KSI_RECORD_CACHE_MAX_BYTES:-536870912}"
echo "  batches:      KSI_PREFETCH_BATCH_COUNT=${KSI_PREFETCH_BATCH_COUNT:-5}"
echo "  batch size:   KSI_BATCH_SIZE=${KSI_BATCH_SIZE:-10000}"
echo "  threshold:    KSI_PREFETCH_TRIGGER_THRESHOLD=${KSI_PREFETCH_TRIGGER_THRESHOLD:-2}"
echo "  compose file: docker-compose.yaml:docker-compose.preload.yaml"
echo "Performance target records: ${REORDERED_PERF_TARGET_RECORDS:-1000000}"

cd "$ENV_DIR"
export COMPOSE_FILE=docker-compose.yaml:docker-compose.preload.yaml
docker --log-level ERROR compose up -d --force-recreate ksi

REORDERED_PERF_BASELINE_LABEL="ksi-preload-baseline" \
REORDERED_PERF_ORDERED_LABEL="ksi-preload-ordered" \
"$SCRIPT_DIR/reordered_perf_run.sh"
