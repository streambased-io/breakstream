#! /bin/bash
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE_DIR=$( cd -- "$SCRIPT_DIR/../../" &> /dev/null && pwd )

source $BASE_DIR/bin/lib/kafka_topic_config.sh
source $BASE_DIR/bin/lib/reordered_perf_cases.sh

echo ""
echo "Copying reordered performance post setup steps to container"
echo ""
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/reordered_perf_post_setup.scala 2>&1 >/dev/null

echo ""
echo "Copying populated reordered performance hotsets to coldset using Spark"
echo ""
docker --log-level ERROR compose exec \
  -e REORDERED_PERF_CASES="${REORDERED_PERF_CASES:-ordered,baseline,kafka}" \
  spark-iceberg sh -c 'cat /tmp/reordered_perf_post_setup.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'

echo ""
echo "Draining reordered performance topics from Kafka"
echo ""
if perf_cases_include baseline
then
  alter_topic_if_exists reordered_perf_customers retention.ms=500,segment.ms=500 &
else
  echo "Skipping drain for reordered_perf_customers"
fi
if perf_cases_include ordered
then
  alter_topic_if_exists reordered_perf_customers_ordered retention.ms=500,segment.ms=500 &
else
  echo "Skipping drain for reordered_perf_customers_ordered"
fi
wait
if perf_cases_include baseline
then
  wait_for_start_offset reordered_perf_customers &
fi
if perf_cases_include ordered
then
  wait_for_start_offset reordered_perf_customers_ordered &
fi
wait
if perf_cases_include baseline
then
  alter_topic_if_exists reordered_perf_customers retention.ms=604800000,segment.ms=604800000 &
fi
if perf_cases_include ordered
then
  alter_topic_if_exists reordered_perf_customers_ordered retention.ms=604800000,segment.ms=604800000 &
fi
wait

echo ""
echo "Reordered performance topic post setup complete"
echo ""
