#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../
cd $SCRIPT_DIR/environment

docker --log-level ERROR compose stop
docker --log-level ERROR compose rm -f

# have to stop background separately
docker --log-level ERROR compose stop shadowtraffic_background
docker --log-level ERROR compose rm -f shadowtraffic_background

if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
then
  rm -rf $SCRIPT_DIR/environment/shadowtraffic
fi

sleep 3
clear
echo "Environment stopped."