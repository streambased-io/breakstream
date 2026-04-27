#! /bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo ""
echo "Copying reordered performance post setup steps to container"
echo ""
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/reordered_perf_post_setup.scala 2>&1 >/dev/null

echo ""
echo "Copying populated reordered_perf_customers hotset to coldset using Spark"
echo ""
docker --log-level ERROR compose exec spark-iceberg sh -c 'cat /tmp/reordered_perf_post_setup.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'

echo ""
echo "Draining reordered_perf_customers from Kafka"
echo ""
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic reordered_perf_customers --add-config retention.ms=500 2>&1 >/dev/null
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic reordered_perf_customers --add-config segment.ms=500 2>&1 >/dev/null
sleep 3
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic reordered_perf_customers --add-config retention.ms=604800000 2>&1 >/dev/null
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic reordered_perf_customers --add-config segment.ms=604800000 2>&1 >/dev/null

echo ""
echo "Reordered performance topic post setup complete"
echo ""
