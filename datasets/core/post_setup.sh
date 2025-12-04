#! /bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# copy for hotset to coldset
docker-compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/post_setup.scala
docker-compose exec spark-iceberg spark-shell --driver-memory 8g -i /tmp/post_setup.scala

docker-compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --delete --topic branches
docker-compose exec schema-registry curl -X DELETE localhost:8081/subjects/branches-value

# drain from kafka
docker-compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic transactions --add-config retention.ms=500
docker-compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic transactions --add-config segment.ms=500
docker-compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic customers --add-config retention.ms=500
docker-compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic customers --add-config segment.ms=500
docker-compose cp $SCRIPT_DIR/scala/check_transactions_count.scala spark-iceberg:/tmp/check_transactions_count.scala
docker-compose exec spark-iceberg spark-shell --driver-memory 8g -i /tmp/check_transactions_count.scala
docker-compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic transactions --add-config retention.ms=604800000
docker-compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic transactions --add-config segment.ms=604800000
