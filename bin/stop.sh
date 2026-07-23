#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../
cd $SCRIPT_DIR/environment

docker --log-level ERROR compose stop
docker --log-level ERROR compose rm -f

# have to stop profiled containers separately as compose may not track them
docker --log-level ERROR compose stop shadowtraffic_background shadowtraffic_setup shadowtraffic_cdc_deletes 2>/dev/null
docker --log-level ERROR compose rm -f shadowtraffic_background shadowtraffic_setup shadowtraffic_cdc_deletes 2>/dev/null

# logistics_live_datagen and logistics_initial_datagen are launched via plain
# `docker run`, not compose, so they aren't covered by the commands above and
# would otherwise leak
docker rm -f logistics_live_datagen 2>/dev/null
docker rm -f logistics_initial_datagen 2>/dev/null

if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
then
  rm -rf $SCRIPT_DIR/environment/shadowtraffic
fi

sleep 3
clear
echo "Environment stopped."