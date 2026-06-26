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
echo "Stopping any previously running live datagen"
echo ""
docker rm -f logistics_live_datagen 2>/dev/null || true

echo ""
echo "Deleting Kafka topics to clear any leftover data from previous sessions"
echo ""
for topic in truck_positions stops delivery_control_events; do
	docker --log-level ERROR compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --delete --topic "$topic" 2>/dev/null || true
done
sleep 5

echo ""
echo "Creating clickstream Kafka topic"
echo ""
docker --log-level ERROR compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --create --topic clickstream --if-not-exists

echo ""
echo "Registering clickstream value schema"
echo ""
docker --log-level ERROR compose exec -T schema-registry curl -s -X POST \
	-H "Content-Type: application/vnd.schemaregistry.v1+json" \
	--data '{"schema":"{\"type\":\"record\",\"name\":\"ClickEvent\",\"fields\":[{\"name\":\"id\",\"type\":\"string\"},{\"name\":\"timestamp\",\"type\":\"long\"},{\"name\":\"url\",\"type\":\"string\"}]}"}' \
	http://localhost:8081/subjects/clickstream-value/versions

echo ""
echo "Running Datagen (in compose network)"
echo ""
DATAGEN_DIR=$SCRIPT_DIR
DATAGEN_TMP=$(mktemp -d)
trap "rm -rf $DATAGEN_TMP" EXIT
cp "$DATAGEN_DIR/datagen.py" "$DATAGEN_DIR/telemetry.py" "$DATAGEN_DIR/config.py" "$DATAGEN_TMP/"

docker run --rm \
	--network environment_default \
	-v "$DATAGEN_TMP:/work" \
	-w /work \
	python:3.11-slim \
	bash -c "pip install --quiet 'confluent-kafka[avro,schemaregistry]' && python datagen.py"

echo ""
echo "Copying post setup steps to container"
echo ""
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/post_setup.scala 2>&1 >/dev/null

echo ""
echo "Copying populated hotset to coldset using Spark"
echo ""
docker --log-level ERROR compose exec spark-iceberg sh -c 'cat /tmp/post_setup.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'

echo ""
echo "Draining hotset data from Kafka (truck_positions — high volume, AI training data lives in coldset)"
echo ""
alter_topic_if_exists truck_positions retention.ms=500
alter_topic_if_exists truck_positions segment.ms=500
alter_topic_if_exists stops retention.ms=500
alter_topic_if_exists stops segment.ms=500
alter_topic_if_exists delivery_control_events retention.ms=500
alter_topic_if_exists delivery_control_events segment.ms=500

docker --log-level ERROR compose cp $SCRIPT_DIR/scala/check_table_count.scala spark-iceberg:/tmp/check_table_count.scala 2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c 'cat /tmp/check_table_count.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'

alter_topic_if_exists truck_positions retention.ms=604800000
alter_topic_if_exists truck_positions segment.ms=604800000
alter_topic_if_exists stops retention.ms=604800000
alter_topic_if_exists stops segment.ms=604800000
alter_topic_if_exists delivery_control_events retention.ms=604800000
alter_topic_if_exists delivery_control_events segment.ms=604800000

echo ""
echo "Starting live datagen (one route every 30s)"
echo ""
docker run -d \
	--name logistics_live_datagen \
	--network environment_default \
	-v "$SCRIPT_DIR:/work" \
	-w /work \
	python:3.11-slim \
	bash -c "pip install --quiet 'confluent-kafka[avro,schemaregistry]' && python live_datagen.py"

echo ""
echo "Post setup complete"
echo ""
sleep 3
