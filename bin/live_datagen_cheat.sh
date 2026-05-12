#!/bin/bash
# Run live_datagen.py for the cheat-detection demo in a container on the compose network.
# Pass --mode live|burst, --cooldown SEC, --max-games N, --cheat-rate F, --archetypes LIST as args.
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DATAGEN_DIR=$SCRIPT_DIR/../datasets/duck_hunt_cheat_detection/datagen

if [ ! -f "$DATAGEN_DIR/live_datagen.py" ]; then
	echo "live_datagen.py not found at $DATAGEN_DIR/live_datagen.py"
	exit 1
fi

DATAGEN_TMP=$(mktemp -d)
trap "rm -rf $DATAGEN_TMP" EXIT
cp "$DATAGEN_DIR/__init__.py" \
   "$DATAGEN_DIR/config.py" \
   "$DATAGEN_DIR/telemetry.py" \
   "$DATAGEN_DIR/profiles.py" \
   "$DATAGEN_DIR/simulator.py" \
   "$DATAGEN_DIR/live_datagen.py" \
   "$DATAGEN_TMP/"

cat > "$DATAGEN_TMP/duck-hunt.properties" <<'EOF'
[kafka]
bootstrap.servers=kafka1:9092
[schema_registry]
url=http://schema-registry:8081
EOF

docker run --rm -it \
	--network environment_default \
	-v "$DATAGEN_TMP:/work" \
	-w /work \
	python:3.11-slim \
	bash -c 'pip install --quiet "confluent-kafka[avro,schemaregistry]" && exec python -u live_datagen.py "$@"' \
	bash "$@"
