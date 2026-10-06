#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../
export BREAKSTREAM_HOST_DIR=$(realpath "$SCRIPT_DIR")

die () {
    echo >&2 "$@"
    exit 1
}
source "$SCRIPT_DIR/bin/lib/demo_common.sh"

compose_has_service() {
  docker --log-level ERROR compose config --services | grep -qx "$1"
}

container_id_for_service() {
  docker --log-level ERROR compose ps -q "$1"
}

service_state() {
  docker --log-level ERROR inspect -f '{{.State.Status}}' "$1"
}

service_health() {
  docker --log-level ERROR inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$1"
}

wait_for_service() {
  SERVICE=$1
  echo "Waiting for $SERVICE"

  for _ in {1..120}
  do
    CONTAINER_ID=$(container_id_for_service "$SERVICE")
    if [ -n "$CONTAINER_ID" ]
    then
      STATE=$(service_state "$CONTAINER_ID")
      HEALTH=$(service_health "$CONTAINER_ID")
      if [ "$STATE" = "running" ] && { [ "$SERVICE" != "schema-registry" ] || [ "$HEALTH" = "healthy" ]; }
      then
        return 0
      fi
    fi
    sleep 2
  done

  echo "Service $SERVICE did not become ready"
  docker --log-level ERROR compose ps -a "$SERVICE"
  return 1
}

wait_for_services() {
  for SERVICE in kafka1 schema-registry minio rest spark-iceberg directstream slipstream ksi
  do
    if compose_has_service "$SERVICE"
    then
      wait_for_service "$SERVICE"
    fi
  done
}

source $SCRIPT_DIR/bin/lib/reordered_perf_cases.sh

perf_setup_file_selected() {
  DATASET_NAME=$1
  SETUP_FILE_NAME=$2

  case "$DATASET_NAME" in
    ksi_reordered_perf|ksi_reordered_perf_isk_hot)
      case "$SETUP_FILE_NAME" in
        setup-ordered.json)
          perf_cases_include ordered
          ;;
        setup-baseline.json)
          perf_cases_include baseline
          ;;
        setup-kafka.json)
          perf_cases_include kafka
          ;;
        *)
          return 0
          ;;
      esac
      ;;
    *)
      return 0
      ;;
  esac
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
  SPEC_NAME="demo_logistics"
fi

# start_tests.sh is for every spec except the ones flagged for bin/start.sh
LAUNCHER=$(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq -r '.launcher // "start_tests"')
if [ "$LAUNCHER" = "start" ]
then
  die "Spec '$SPEC_NAME' is configured to run via bin/start.sh, not bin/start_tests.sh. Run: ./bin/start.sh $SPEC_NAME"
fi

# make docker compose
cat $SCRIPT_DIR/environment/header-docker-compose.part.yaml > $SCRIPT_DIR/environment/docker-compose.yaml
for COMPONENT in $(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq .components[] | sed -e 's/"//g')
do
  cat $SCRIPT_DIR/environment/$COMPONENT-docker-compose.part.yaml >> $SCRIPT_DIR/environment/docker-compose.yaml
done

# start services
echo "starting service"
cd $SCRIPT_DIR/environment
docker --log-level ERROR compose build
docker --log-level ERROR compose pull
docker --log-level ERROR compose up -d
wait_for_services
clear
echo "done starting service"

# prepare shadowtraffic
if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
then
    rm -rf $SCRIPT_DIR/environment/shadowtraffic
fi
mkdir -p $SCRIPT_DIR/environment/shadowtraffic
prepare_shadowtraffic_license
clear

# load datasets

for DATASET in $(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq .setup_datasets[] | sed -e 's/"//g')
do

  # run setup
  if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
  then
      rm -rf $SCRIPT_DIR/environment/shadowtraffic/*
  fi
  cp -R $SCRIPT_DIR/datasets/$DATASET/* $SCRIPT_DIR/environment/shadowtraffic
  SETUP_CONTAINERS=()
  ALL_SETUP_CONTAINERS=()
  # setup.json is the canonical single-file setup and takes priority when present
  # (e.g. datasets/demo has both setup.json and setup-evolved.json, the latter is
  # not part of initial setup - it's loaded later by tests/demo_core/run.sh).
  # setup-*.json is a fallback for datasets that split setup into multiple files
  # (ksi_reordered_perf, ksi_reordered_perf_isk_hot), which have no setup.json.
  # Neither file is required - a dataset may load its own data some other way
  # (e.g. datasets/logistics does this in post_setup.sh), so finding none here
  # just skips the shadowtraffic setup step rather than failing.
  SETUP_FILES=()
  if [ -f $SCRIPT_DIR/environment/shadowtraffic/setup.json ]
  then
    SETUP_FILES+=("setup.json")
  elif compgen -G "$SCRIPT_DIR/environment/shadowtraffic/setup-*.json" > /dev/null
  then
    for SETUP_PATH in $SCRIPT_DIR/environment/shadowtraffic/setup-*.json
    do
      SETUP_FILE=$(basename "$SETUP_PATH")
      if perf_setup_file_selected "$DATASET" "$SETUP_FILE"
      then
        SETUP_FILES+=("$SETUP_FILE")
      else
        echo "Skipping $SETUP_FILE for REORDERED_PERF_CASES=${REORDERED_PERF_CASES:-ordered,baseline,kafka}"
      fi
    done
  fi

  if [ ${#SETUP_FILES[@]} -eq 0 ]
  then
    echo "No setup files found for dataset $DATASET, skipping shadowtraffic setup step"
  fi

  for SETUP_FILE in "${SETUP_FILES[@]}"
  do
    SETUP_NAME=$(echo "$SETUP_FILE" | sed -e 's/\.json$//' -e 's/[^a-zA-Z0-9_-]/_/g')
    CONTAINER_NAME="shadowtraffic_${DATASET}_${SETUP_NAME}_${RANDOM}"
    CONTAINER_ID=$(docker --log-level ERROR compose run -d --name "$CONTAINER_NAME" shadowtraffic_setup --config "/etc/shadowtraffic/$SETUP_FILE" --seed 1234)
    SETUP_CONTAINERS+=("$CONTAINER_ID")
    ALL_SETUP_CONTAINERS+=("$CONTAINER_ID")
  done

  if [ ${#SETUP_CONTAINERS[@]} -gt 0 ]
  then
    clear
  fi

  while [ ${#SETUP_CONTAINERS[@]} -gt 0 ]
  do
    RUNNING_CONTAINERS=()
    for CONTAINER_ID in "${SETUP_CONTAINERS[@]}"
    do
      if [ "$(docker --log-level ERROR inspect -f '{{.State.Running}}' "$CONTAINER_ID")" = "true" ]
      then
        RUNNING_CONTAINERS+=("$CONTAINER_ID")
      fi
    done
    SETUP_CONTAINERS=("${RUNNING_CONTAINERS[@]}")

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

  for CONTAINER_ID in "${ALL_SETUP_CONTAINERS[@]}"
  do
    EXIT_CODE=$(docker --log-level ERROR inspect -f '{{.State.ExitCode}}' "$CONTAINER_ID")
    if [ "$EXIT_CODE" != "0" ]
    then
      echo "ShadowTraffic setup container $CONTAINER_ID failed with exit code $EXIT_CODE"
      docker --log-level ERROR logs "$CONTAINER_ID"
      exit 112
    fi
  done

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
$SCRIPT_DIR/bin/stop.sh

if [[ $EXITCODE != 0 ]]
then
  echo "TESTS FAILED"
else
  echo "TESTS PASSED"
fi

exit $EXITCODE
