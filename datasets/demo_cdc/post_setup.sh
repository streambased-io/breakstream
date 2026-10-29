#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE_DIR=$( cd -- "$SCRIPT_DIR/../../" &> /dev/null && pwd )

source $BASE_DIR/bin/lib/demo_common.sh
source $BASE_DIR/bin/lib/union_roll.sh

# stop any previously running live datagen
docker rm -f cdc_live_datagen 2>/dev/null >/dev/null || true

# load the initial 500 PENDING orders (in compose network)
DATAGEN_TMP=$(mktemp -d)
trap "rm -rf $DATAGEN_TMP" EXIT
cp "$SCRIPT_DIR/datagen.py" "$SCRIPT_DIR/orders.py" "$SCRIPT_DIR/config.py" "$DATAGEN_TMP/"

# named so a stale one from an interrupted previous run can be found and removed
docker rm -f cdc_initial_datagen 2>/dev/null >/dev/null || true
docker run --rm \
	--name cdc_initial_datagen \
	--network environment_default \
	-e PYTHONDONTWRITEBYTECODE=1 \
	-v "$DATAGEN_TMP:/work" \
	-w /work \
	python:3.11-slim \
	bash -c "pip install --quiet 'confluent-kafka[avro,schemaregistry]' && python datagen.py" >/dev/null 2>&1
if [[ $? != 0 ]]
then
  echo "Initial CDC datagen failed"
  exit 1
fi

# roll the initial CDC orders from hotset to coldset
demo_paragraph "cdc_hotset_to_coldset"
roll_topics orders > /dev/null || { echo "Initial CDC orders roll failed"; exit 1; }

# start live datagen: new orders + PENDING -> SHIPPED updates
docker run -d \
	--name cdc_live_datagen \
	--network environment_default \
	-e PYTHONDONTWRITEBYTECODE=1 \
	-v "$SCRIPT_DIR:/work" \
	-w /work \
	python:3.11-slim \
	bash -c "pip install --quiet 'confluent-kafka[avro,schemaregistry]' && python live_datagen.py" >/dev/null

clear
demo_paragraph "post_setup_complete"

exit 0
