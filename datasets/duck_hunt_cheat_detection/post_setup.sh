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
echo "Running Datagen (in compose network)"
echo ""
DATAGEN_DIR=$SCRIPT_DIR/datagen
DATAGEN_TMP=$(mktemp -d)
trap "rm -rf $DATAGEN_TMP" EXIT
cp "$DATAGEN_DIR/__init__.py" \
   "$DATAGEN_DIR/config.py" \
   "$DATAGEN_DIR/telemetry.py" \
   "$DATAGEN_DIR/profiles.py" \
   "$DATAGEN_DIR/simulator.py" \
   "$DATAGEN_DIR/setup_datagen.py" \
   "$DATAGEN_TMP/"
cat > "$DATAGEN_TMP/duck-hunt.properties" <<'EOF'
[kafka]
bootstrap.servers=kafka1:9092
[schema_registry]
url=http://schema-registry:8081
EOF

docker run --rm \
	--network environment_default \
	-v "$DATAGEN_TMP:/work" \
	-w /work \
	python:3.11-slim \
	bash -c "pip install --quiet 'confluent-kafka[avro,schemaregistry]' && python setup_datagen.py"

echo ""
echo "Copying post setup steps to container"
echo ""
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/post_setup.scala 2>&1 >/dev/null

echo ""
echo "Copying populated hotset to coldset using Spark"
echo ""
docker --log-level ERROR compose exec spark-iceberg sh -c 'cat /tmp/post_setup.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'

echo ""
echo "Draining hotset data from Kafka"
echo ""
alter_topic_if_exists gun_positions retention.ms=500
alter_topic_if_exists gun_positions segment.ms=500
alter_topic_if_exists shots retention.ms=500
alter_topic_if_exists shots segment.ms=500
alter_topic_if_exists control_events retention.ms=500
alter_topic_if_exists control_events segment.ms=500
alter_topic_if_exists duck_spawns retention.ms=500
alter_topic_if_exists duck_spawns segment.ms=500

docker --log-level ERROR compose cp $SCRIPT_DIR/scala/check_table_count.scala spark-iceberg:/tmp/check_table_count.scala 2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c 'cat /tmp/check_table_count.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'

alter_topic_if_exists gun_positions retention.ms=604800000
alter_topic_if_exists gun_positions segment.ms=604800000
alter_topic_if_exists shots retention.ms=604800000
alter_topic_if_exists shots segment.ms=604800000
alter_topic_if_exists control_events retention.ms=604800000
alter_topic_if_exists control_events segment.ms=604800000
alter_topic_if_exists duck_spawns retention.ms=604800000
alter_topic_if_exists duck_spawns segment.ms=604800000

echo ""
echo "Post setup complete"
echo ""
sleep 3
