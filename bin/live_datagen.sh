#!/bin/bash
# Run live_datagen.py in a container on the compose network so kafka1/schema-registry resolve.
# Pass --mode live|burst, --cooldown SEC, --max-games N as args.
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DATAGEN_DIR=$SCRIPT_DIR/../../duck-hunt-demo

if [ ! -f "$DATAGEN_DIR/live_datagen.py" ]; then
	echo "live_datagen.py not found at $DATAGEN_DIR/live_datagen.py"
	exit 1
fi

DATAGEN_TMP=$(mktemp -d)
trap "rm -rf $DATAGEN_TMP" EXIT
cp "$DATAGEN_DIR/datagen.py" \
	"$DATAGEN_DIR/telemetry.py" \
	"$DATAGEN_DIR/config.py" \
	"$DATAGEN_DIR/live_datagen.py" \
	"$DATAGEN_TMP/"

cat > "$DATAGEN_TMP/duck-hunt.properties" <<'EOF'
[display]
scale_x=3
scale_y=2.5
[telemetry]
enabled=true
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
