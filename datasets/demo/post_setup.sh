#! /bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
GREEN='\033[0;32m'
NC='\033[0m' # No Color


wait_for_start_offset() {
  TOPIC=$1
  START_OFFSET=0
  while [ $START_OFFSET -eq 0 ]
  do
    OFFSET_SHELL_OUT=$(docker --log-level ERROR compose exec kafka1 kafka-get-offsets --time -2 --broker-list kafka1:9092 --topic $TOPIC)
    START_OFFSET=$(echo $OFFSET_SHELL_OUT | cut -d':' -f3)
    sleep 1
  done
}

# copy from hotset to coldset
echo ""
echo -e "${GREEN} Copying post setup steps to container ${NC}"
echo ""
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/post_setup.scala 2>&1 >/dev/null

echo ""
echo -e "${GREEN} Copying populated hotset to coldset using Spark ${NC}"
echo ""
docker --log-level ERROR compose exec spark-iceberg spark-shell --driver-memory 8g -i /tmp/post_setup.scala 2>&1 >/dev/null

echo ""
echo -e "${GREEN} Deleting coldset only topic ${NC}"
echo ""
docker --log-level ERROR compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --delete --topic branches 2>&1 >/dev/null
docker --log-level ERROR compose exec schema-registry curl -s -X DELETE localhost:8081/subjects/branches-value 2>&1 >/dev/null

echo ""
echo -e "${GREEN} Draining hotset data from Kafka ${NC}"
echo ""

# drain from kafka
# update topic configs
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic transactions --add-config retention.ms=500 2>&1 >/dev/null
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic transactions --add-config segment.ms=500 2>&1 >/dev/null
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic customers --add-config retention.ms=500 2>&1 >/dev/null
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic customers --add-config segment.ms=500 2>&1 >/dev/null

# confirm data has been deleted
wait_for_start_offset customers
wait_for_start_offset transactions

docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic transactions --add-config retention.ms=604800000 2>&1 >/dev/null
docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic transactions --add-config segment.ms=604800000 2>&1 >/dev/null

echo ""
echo -e "${GREEN} Post setup complete ${NC}"
echo ""
sleep 3