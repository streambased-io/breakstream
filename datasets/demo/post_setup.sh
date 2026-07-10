#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE_DIR=$( cd -- "$SCRIPT_DIR/../../" &> /dev/null && pwd )

source $BASE_DIR/bin/lib/demo_common.sh
source $BASE_DIR/bin/lib/kafka_topic_config.sh

# copy from hotset to coldset
demo_paragraph "hotset_to_coldset"
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/post_setup.scala 2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c 'cat /tmp/post_setup.scala | spark-shell --driver-memory 8g 2>&1 >/dev/null'

docker --log-level ERROR compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --delete --topic branches 2>&1 >/dev/null
docker --log-level ERROR compose exec schema-registry curl -s -X DELETE localhost:8081/subjects/branches-value 2>&1 >/dev/null

# drain from kafka
# update topic configs
alter_topic_if_exists transactions retention.ms=500,segment.ms=500 &
alter_topic_if_exists customers retention.ms=500,segment.ms=500 &
wait

# confirm data has been deleted
wait_for_start_offset customers &
wait_for_start_offset transactions &
wait

alter_topic_if_exists transactions retention.ms=604800000,segment.ms=604800000 &
wait

clear
demo_paragraph "post_setup_complete"

exit 0
