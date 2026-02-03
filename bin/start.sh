#! /bin/bash

export SLEEP_TIME=20
DEMO_MODE=false
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../

die () {
    echo >&2 "$@"
    exit 1
}

demo_paragraph() {
    if [ "$DEMO_MODE" = "true" ]
    then
      $SCRIPT_DIR/bin/demo_script.sh $1
      echo "Press any key to continue"
      read -s -t$SLEEP_TIME -n1 key
      if [ "$DEBUG_MODE" != "true" ]
      then
        clear
      fi
    fi
}

# check for prerequisites
command -v curl > /dev/null 2>&1 || die "curl is required but not installed"
command -v jq > /dev/null 2>&1 || die "jq is required but not installed"
command -v docker > /dev/null 2>&1 || die "docker is required but not installed"

# setup and validate
if [ "$#" -eq 1 ]
then
  ls $SCRIPT_DIR/specs/$1 > /dev/null 2>&1  || die "Test case not found, $1 provided"
  SPEC_NAME=$1
else
  SPEC_NAME="demo_core"
fi

# are we running a demo?
if [[  $SPEC_NAME == demo_* ]]
then
  export DEMO_MODE=true
fi

demo_paragraph "header"
demo_paragraph "architecture"
demo_paragraph "deep_dive"
demo_paragraph "environment"

# make docker compose
cat $SCRIPT_DIR/environment/header-docker-compose.part.yaml > $SCRIPT_DIR/environment/docker-compose.yaml
for COMPONENT in $(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq .components[] | sed -e 's/"//g')
do
  cat $SCRIPT_DIR/environment/$COMPONENT-docker-compose.part.yaml >> $SCRIPT_DIR/environment/docker-compose.yaml
done

# start services
cd $SCRIPT_DIR/environment
docker --log-level ERROR compose pull
docker --log-level ERROR compose up -d
clear

# prepare shadowtraffic
if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
then
    rm -rf $SCRIPT_DIR/environment/shadowtraffic
fi
mkdir -p $SCRIPT_DIR/environment/shadowtraffic
curl  https://raw.githubusercontent.com/ShadowTraffic/shadowtraffic-examples/refs/heads/master/free-trial-license.env > $SCRIPT_DIR/environment/shadowtraffic_license.env
clear

demo_paragraph "containers"

# load datasets

for DATASET in $(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq .setup_datasets[] | sed -e 's/"//g')
do

  demo_paragraph "setup_intro"
  demo_paragraph "data_to_kafka"

  # run setup
  if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
  then
      rm -rf $SCRIPT_DIR/environment/shadowtraffic/*
  fi
  cp -R $SCRIPT_DIR/datasets/$DATASET/* $SCRIPT_DIR/environment/shadowtraffic
  if [ -f $SCRIPT_DIR/environment/shadowtraffic/setup.json ]
  then
    docker --log-level ERROR compose up -d shadowtraffic_setup
    clear
  fi
  while [ ! -z "$(docker --log-level ERROR compose ps -q shadowtraffic_setup)" ]
  do
    echo "Loading data to topics:"
    for topic in $(docker --log-level ERROR compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --list | grep -v __consumer_offsets | grep -v _schemas)
    do
      docker --log-level ERROR compose exec kafka1 kafka-run-class kafka.tools.GetOffsetShell   --broker-list kafka1:9092 --topic $topic
    done
    echo "."
    sleep 1
    echo ".."
    sleep 1
    echo "..."
    sleep 1
    clear
  done

  demo_paragraph "kafka_to_iceberg"
  if [ -f $SCRIPT_DIR/environment/shadowtraffic/post_setup.sh ]
  then
    $SCRIPT_DIR/environment/shadowtraffic/post_setup.sh
  fi
  if [[ $? != 0 ]]
  then
    # setup failed
    echo "FAILED TO SETUP DATASET $DATASET: POST SETUP STEPS FAILED"
    exit 113
  fi
done

# load background datasets
demo_paragraph "new_data"
sleep 3
clear
if [[ "$(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq '.background_dataset')" = "null" ]];
then
  echo "No background dataset specified, skipping background load."
else
  BACKGROUND_DATASET=$(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq .background_dataset | sed -e 's/"//g')
  if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
  then
    rm -rf $SCRIPT_DIR/environment/shadowtraffic/*
  fi
  cp -R $SCRIPT_DIR/datasets/$BACKGROUND_DATASET/* $SCRIPT_DIR/environment/shadowtraffic
  if [ -f $SCRIPT_DIR/environment/shadowtraffic/background.json ]
  then
    docker --log-level ERROR compose up -d shadowtraffic_background
  fi
fi
sleep 3

# exit if setup mode
if [ "$SETUP_MODE" = "true" ]
then
  echo "Setup mode is enabled, no tests will be run. Run ./bin/stop.sh to stop the environment."
  exit 0
fi

# run tests
export EXITCODE=0
for TEST_NAME in $(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq .tests[] | sed -e 's/"//g')
do
  clear
  $SCRIPT_DIR/tests/$TEST_NAME/run.sh
  if [[ $? != 0 ]]
  then
    echo "TEST $TEST_NAME FAILED"
    export EXITCODE=114
  fi
done

# tear down
demo_paragraph "finish"
if [ "$DEMO_MODE" != "true" ]
then
  $SCRIPT_DIR/bin/stop.sh

  if [[ $EXITCODE != 0 ]]
  then
    echo "TESTS FAILED"
  else
    echo "TESTS PASSED"
  fi
fi

exit $EXITCODE
