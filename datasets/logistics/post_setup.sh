#! /bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE_DIR=$( cd -- "$SCRIPT_DIR/../../" &> /dev/null && pwd )

source $BASE_DIR/bin/lib/kafka_topic_config.sh

GREEN='\033[0;32m'
NC='\033[0m'
log_step() {
	echo -e "${GREEN}$1${NC}"
}

echo ""
log_step "Stopping any previously running live datagen"
echo ""
docker rm -f logistics_live_datagen 2>/dev/null || true

echo ""
log_step "Deleting Kafka topics to clear any leftover data from previous sessions"
echo ""
for topic in truck_positions stops delivery_control_events; do
	docker --log-level ERROR compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --delete --topic "$topic" >/dev/null 2>&1 || true
done
sleep 2

echo ""
log_step "Creating clickstream Kafka topic"
echo ""
docker --log-level ERROR compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --create --topic clickstream --if-not-exists

echo ""
log_step "Registering clickstream value schema"
echo ""
docker --log-level ERROR compose exec -T schema-registry curl -s -X POST \
	-H "Content-Type: application/vnd.schemaregistry.v1+json" \
	--data '{"schema":"{\"type\":\"record\",\"name\":\"ClickEvent\",\"fields\":[{\"name\":\"id\",\"type\":\"string\"},{\"name\":\"timestamp\",\"type\":\"long\"},{\"name\":\"url\",\"type\":\"string\"}]}"}' \
	http://localhost:8081/subjects/clickstream-value/versions > /dev/null

echo ""
log_step "Running Datagen (in compose network)"
echo ""
DATAGEN_DIR=$SCRIPT_DIR
DATAGEN_TMP=$(mktemp -d)
trap "rm -rf $DATAGEN_TMP" EXIT
cp "$DATAGEN_DIR/datagen.py" "$DATAGEN_DIR/telemetry.py" "$DATAGEN_DIR/config.py" "$DATAGEN_TMP/"

# named (unlike a plain `docker run`'s random name) so a stale one from an
# interrupted previous run can be found and removed, same as logistics_live_datagen below
docker rm -f logistics_initial_datagen 2>/dev/null || true
docker run --rm \
	--name logistics_initial_datagen \
	--network environment_default \
	-e PYTHONDONTWRITEBYTECODE=1 \
	-v "$DATAGEN_TMP:/work" \
	-w /work \
	python:3.11-slim \
	bash -c "pip install --quiet 'confluent-kafka[avro,schemaregistry]' && python datagen.py"

echo ""
log_step "Copying post setup steps to container"
echo ""
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/post_setup.scala 2>&1 >/dev/null

echo ""
log_step "Copying populated hotset to coldset using Spark"
echo ""
docker --log-level ERROR compose exec -T spark-iceberg sh -c 'cat /tmp/post_setup.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'

echo ""
log_step "Draining hotset data from Kafka (truck_positions — high volume, AI training data lives in coldset)"
echo ""
alter_topic_if_exists truck_positions retention.ms=500,segment.ms=500 &
alter_topic_if_exists stops retention.ms=500,segment.ms=500 &
alter_topic_if_exists delivery_control_events retention.ms=500,segment.ms=500 &
wait

docker --log-level ERROR compose cp $SCRIPT_DIR/scala/check_table_count.scala spark-iceberg:/tmp/check_table_count.scala 2>&1 >/dev/null
docker --log-level ERROR compose exec -T spark-iceberg sh -c 'cat /tmp/check_table_count.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'

alter_topic_if_exists truck_positions retention.ms=604800000,segment.ms=604800000 &
alter_topic_if_exists stops retention.ms=604800000,segment.ms=604800000 &
alter_topic_if_exists delivery_control_events retention.ms=604800000,segment.ms=604800000 &
wait

echo ""
log_step "Starting live datagen (one route every 30s)"
echo ""
docker run -d \
	--name logistics_live_datagen \
	--network environment_default \
	-e PYTHONDONTWRITEBYTECODE=1 \
	-v "$SCRIPT_DIR:/work" \
	-w /work \
	python:3.11-slim \
	bash -c "pip install --quiet 'confluent-kafka[avro,schemaregistry]' && python live_datagen.py"

echo ""
log_step "Post setup complete"
echo ""
if [ "${INTERACTIVE_MODE}" = "true" ]; then sleep 3; fi
