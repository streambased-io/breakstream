#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../
cd $SCRIPT_DIR/environment

docker-compose stop
docker-compose rm -f

# have to stop background separately
docker-compose stop shadowtraffic_background
docker-compose rm -f shadowtraffic_background

if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
then
  rm -rf $SCRIPT_DIR/environment/shadowtraffic
fi