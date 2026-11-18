#! /bin/bash

export SLEEP_TIME=20
DEMO_MODE=false
export INTERACTIVE_MODE=${INTERACTIVE_MODE:-false}
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../
export BREAKSTREAM_HOST_DIR=$(realpath "$SCRIPT_DIR")

die () {
    echo >&2 "$@"
    exit 1
}

source $SCRIPT_DIR/bin/lib/demo_common.sh

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
  SPEC_NAME="demo_oil_and_gas"
fi

# are we running a demo?
if [[  $SPEC_NAME == demo_* ]]
then
  export DEMO_MODE=true
fi

# start.sh is only for specs flagged for it; everything else runs via start_tests.sh
LAUNCHER=$(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq -r '.launcher // "start_tests"')
if [ "$LAUNCHER" != "start" ]
then
  die "Spec '$SPEC_NAME' is configured to run via bin/start_tests.sh, not bin/start.sh. Run: ./bin/start_tests.sh $SPEC_NAME"
fi

demo_paragraph "header"
demo_paragraph "architecture"
demo_paragraph "deep_dive"
demo_paragraph "environment"

# topics Slipstream lists on its overview screen; empty keeps Slipstream's own default
export SLIPSTREAM_TOPICS=$(jq -r '(.slipstream_topics // []) | join(",")' $SCRIPT_DIR/specs/$SPEC_NAME/spec.json)

# make docker compose
cat $SCRIPT_DIR/environment/header-docker-compose.part.yaml > $SCRIPT_DIR/environment/docker-compose.yaml
for COMPONENT in $(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq .components[] | sed -e 's/"//g')
do
  cat $SCRIPT_DIR/environment/$COMPONENT-docker-compose.part.yaml >> $SCRIPT_DIR/environment/docker-compose.yaml
done

# a spec with the jupyter component mounts (and opens) the notebook from its first setup dataset's notebooks/ dir
DEMO_NOTEBOOK=""
if jq -e '.components | index("jupyter")' $SCRIPT_DIR/specs/$SPEC_NAME/spec.json > /dev/null
then
  DEMO_DATASET=$(jq -r '.setup_datasets[0] // empty' $SCRIPT_DIR/specs/$SPEC_NAME/spec.json)
  export DEMO_NOTEBOOK_DIR="$BREAKSTREAM_HOST_DIR/datasets/$DEMO_DATASET/notebooks"
  DEMO_NOTEBOOK=$(basename "$(ls $DEMO_NOTEBOOK_DIR/*.ipynb 2>/dev/null | head -1)" 2>/dev/null)
  [ -n "$DEMO_NOTEBOOK" ] || die "Spec '$SPEC_NAME' uses jupyter but datasets/$DEMO_DATASET/notebooks has no .ipynb"
  # Slipstream's /dashboard/notebook page embeds this (it otherwise defaults to logistics_demo.ipynb)
  export SLIPSTREAM_NOTEBOOK_URL="http://localhost:8889/notebooks/$DEMO_NOTEBOOK"
fi

# start services
cd $SCRIPT_DIR/environment
# SKIP_PULL=true uses whatever images are already local (e.g. your own builds under the default tags)
if [ "$SKIP_PULL" = "true" ]
then
  echo "SKIP_PULL=true: not pulling images"
else
  docker --log-level ERROR compose pull --ignore-pull-failures
fi
docker --log-level ERROR compose up -d
clear

# prepare shadowtraffic
if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
then
    rm -rf $SCRIPT_DIR/environment/shadowtraffic
fi
mkdir -p $SCRIPT_DIR/environment/shadowtraffic
# only specs with a ShadowTraffic datagen component need the licence
if grep -q "image: shadowtraffic/" $SCRIPT_DIR/environment/docker-compose.yaml
then
  curl  https://raw.githubusercontent.com/ShadowTraffic/shadowtraffic-examples/refs/heads/master/free-trial-license.env > $SCRIPT_DIR/environment/shadowtraffic_license.env
fi
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
if [ "${INTERACTIVE_MODE}" = "true" ]; then sleep 3; fi
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
if [ "${INTERACTIVE_MODE}" = "true" ]; then sleep 3; fi

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

# launch the demo notebook (specs with the jupyter component)
if [ -n "$DEMO_NOTEBOOK" ]
then
  echo "Waiting for Jupyter notebook server..."
  NOTEBOOK_URL=""
  ATTEMPTS=0
  while [ -z "$NOTEBOOK_URL" ] && [ $ATTEMPTS -lt 30 ]
  do
    NOTEBOOK_URL=$(docker --log-level ERROR compose logs jupyter 2>/dev/null \
      | grep -o 'http://127\.0\.0\.1:8888[^[:space:]]*' | head -1 \
      | sed -e 's/:8888/:8889/' -e "s#/tree#/notebooks/$DEMO_NOTEBOOK#")
    if [ -z "$NOTEBOOK_URL" ]; then
      sleep 2
      ATTEMPTS=$((ATTEMPTS + 1))
    fi
  done

  # the wait above only checks Jupyter is up; the notebook is opened inside Slipstream
  OPEN_URL="http://localhost:3000/dashboard/notebook"

  echo ""
  echo "================================================"
  echo "  Demo notebook ($DEMO_NOTEBOOK) is ready"
  echo ""
  echo "  Open: $OPEN_URL"
  echo ""
  echo "  Run cells from top to bottom."
  echo ""
  echo "  When finished, run: ./bin/stop.sh"
  echo "================================================"
  echo ""

  if command -v xdg-open > /dev/null 2>&1; then
    xdg-open "$OPEN_URL"
  elif command -v open > /dev/null 2>&1; then
    open "$OPEN_URL"
  fi
fi
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
