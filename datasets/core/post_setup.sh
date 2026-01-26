#! /bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# copy for hotset to coldset
echo ""
echo "Copying post setup steps to container"
echo ""
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/post_setup.scala 2>&1 >/dev/null

echo ""
echo "Copying populated hotset to cold set using Spark"
echo ""
docker --log-level ERROR compose exec spark-iceberg spark-shell --driver-memory 8g -i /tmp/post_setup.scala 2>&1 >/dev/null

echo ""
echo "Deleting coldset only topic"
echo ""
docker --log-level ERROR compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --delete --topic branches 2>&1 >/dev/null
docker --log-level ERROR compose exec schema-registry curl -s -X DELETE localhost:8081/subjects/branches-value 2>&1 >/dev/null

echo ""
echo "Draining hotset data from Kafka"
echo ""
# drain from kafka
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic transactions --add-config retention.ms=500 2>&1 >/dev/null
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic transactions --add-config segment.ms=500 2>&1 >/dev/null
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic customers --add-config retention.ms=500 2>&1 >/dev/null
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic customers --add-config segment.ms=500 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/check_transactions_count.scala spark-iceberg:/tmp/check_transactions_count.scala 2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg spark-shell --driver-memory 8g -i /tmp/check_transactions_count.scala 2>&1 >/dev/null
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic transactions --add-config retention.ms=604800000 2>&1 >/dev/null
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic transactions --add-config segment.ms=604800000 2>&1 >/dev/null

echo ""
echo "Post setup complete"
echo ""
sleep 3