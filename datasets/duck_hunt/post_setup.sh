#! /bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

topic_exists() {
	local topic=$1
	docker --log-level ERROR compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --list | grep -qx "$topic"
}

alter_topic_if_exists() {
	local topic=$1
	local config=$2
	if topic_exists "$topic"; then
		docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic "$topic" --add-config "$config" 2>&1 >/dev/null
	else
		echo "Skipping config update for missing topic: $topic"
	fi
}

echo ""
echo "Running Datagen"
echo ""
python3 $SCRIPT_DIR/../../../duck-hunt-demo/datagen.py

echo ""
echo "Copying post setup steps to container"
echo ""
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/post_setup.scala 2>&1 >/dev/null

echo ""
echo "Copying populated hotset to coldset using Spark"
echo ""
docker --log-level ERROR compose exec spark-iceberg sh -c 'cat /tmp/post_setup.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'

echo ""
echo "Draining hotset data from Kafka (gun_positions — high volume, AI training data lives in coldset)"
echo ""
alter_topic_if_exists gun_positions retention.ms=500
alter_topic_if_exists gun_positions segment.ms=500
alter_topic_if_exists shots retention.ms=500
alter_topic_if_exists shots segment.ms=500
alter_topic_if_exists control_events retention.ms=500
alter_topic_if_exists control_events segment.ms=500

docker --log-level ERROR compose cp $SCRIPT_DIR/scala/check_transactions_count.scala spark-iceberg:/tmp/check_transactions_count.scala 2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c 'cat /tmp/check_transactions_count.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'

alter_topic_if_exists gun_positions retention.ms=604800000
alter_topic_if_exists gun_positions segment.ms=604800000
alter_topic_if_exists shots retention.ms=604800000
alter_topic_if_exists shots segment.ms=604800000
alter_topic_if_exists control_events retention.ms=604800000
alter_topic_if_exists control_events segment.ms=604800000

echo ""
echo "Post setup complete"
echo ""
sleep 3
