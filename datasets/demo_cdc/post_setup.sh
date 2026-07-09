#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE_DIR=$( cd -- "$SCRIPT_DIR/../../" &> /dev/null && pwd )

source $BASE_DIR/bin/lib/demo_common.sh

# copy initial CDC orders from hotset to coldset
demo_paragraph "cdc_hotset_to_coldset"
#sleep 100
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/cdc_post_setup.scala 2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c 'cat /tmp/cdc_post_setup.scala | spark-shell --driver-memory 8g 2>&1 >/dev/null'

clear
demo_paragraph "post_setup_complete"

exit 0
