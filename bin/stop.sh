#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../
cd $SCRIPT_DIR/environment

docker-compose stop
docker-compose rm -f

if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
then
  rm -rf $SCRIPT_DIR/environment/shadowtraffic
fi