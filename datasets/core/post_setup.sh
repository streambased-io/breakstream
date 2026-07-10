#! /bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE_DIR=$( cd -- "$SCRIPT_DIR/../../" &> /dev/null && pwd )

source $BASE_DIR/bin/lib/kafka_topic_config.sh

# copy for hotset to coldset
echo ""
echo "Copying post setup steps to container"
echo ""
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/post_setup.scala 2>&1 >/dev/null

echo ""
echo "Copying populated hotset to cold set using Spark"
echo ""
docker --log-level ERROR compose exec spark-iceberg sh -c 'cat /tmp/post_setup.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'

echo ""
echo "Deleting coldset only topic"
echo ""
docker --log-level ERROR compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --delete --topic branches 2>&1 >/dev/null
docker --log-level ERROR compose exec schema-registry curl -s -X DELETE localhost:8081/subjects/branches-value 2>&1 >/dev/null
echo ""
echo "Draining hotset data from Kafka"
echo ""
# drain from kafka
alter_topic_if_exists transactions retention.ms=500,segment.ms=500 &
alter_topic_if_exists customers retention.ms=500,segment.ms=500 &
alter_topic_if_exists stores retention.ms=500,segment.ms=500 &
wait
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/check_transactions_count.scala spark-iceberg:/tmp/check_transactions_count.scala 2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c 'cat /tmp/check_transactions_count.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'
alter_topic_if_exists transactions retention.ms=604800000,segment.ms=604800000 &
alter_topic_if_exists stores retention.ms=604800000,segment.ms=604800000 &
wait

echo ""
echo "Post setup complete"
echo ""
sleep 3