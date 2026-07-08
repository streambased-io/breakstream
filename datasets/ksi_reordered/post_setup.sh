#! /bin/bash
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE_DIR=$( cd -- "$SCRIPT_DIR/../../" &> /dev/null && pwd )

source $BASE_DIR/bin/lib/kafka_topic_config.sh

echo ""
echo "Copying reordered post setup steps to container"
echo ""
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/reordered_post_setup.scala 2>&1 >/dev/null

echo ""
echo "Copying populated reordered_customers hotset to coldset using Spark"
echo ""
docker --log-level ERROR compose exec spark-iceberg sh -c 'cat /tmp/reordered_post_setup.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'

echo ""
echo "Draining reordered_customers from Kafka"
echo ""
alter_topic_if_exists reordered_customers retention.ms=500,segment.ms=500
wait_for_start_offset reordered_customers
alter_topic_if_exists reordered_customers retention.ms=604800000,segment.ms=604800000

echo ""
echo "Reordered topic post setup complete"
echo ""
