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

perf_cases_include() {
  CASE_ID=$1
  RAW_CASES="${REORDERED_PERF_CASES:-ordered,baseline,kafka}"

  if [ -z "$RAW_CASES" ]
  then
    return 0
  fi

  IFS=',' read -ra TOKENS <<< "$RAW_CASES"
  for TOKEN in "${TOKENS[@]}"
  do
    TOKEN=$(echo "$TOKEN" | tr '[:upper:]' '[:lower:]' | xargs)
    if [ "$TOKEN" = "all" ]
    then
      return 0
    fi

    case "$CASE_ID:$TOKEN" in
      ordered:ordered|ordered:ksi-ordered|ordered:ordered-ksi|ordered:reordered_perf_customers_ordered|ordered:${REORDERED_PERF_ORDERED_LABEL:-ksi-ordered-coldset})
        return 0
        ;;
      baseline:baseline|baseline:ksi-baseline|baseline:normal|baseline:reordered|baseline:reordered_perf_customers|baseline:${REORDERED_PERF_BASELINE_LABEL:-ksi-baseline})
        return 0
        ;;
      kafka:kafka|kafka:normal-kafka|kafka:reordered_perf_customers_kafka)
        return 0
        ;;
    esac
  done

  return 1
}

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
  SETUP_CONTAINERS=()
  ALL_SETUP_CONTAINERS=()
  SETUP_FILES=()
  if compgen -G "$SCRIPT_DIR/environment/shadowtraffic/setup-*.json" > /dev/null
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
  elif [ -f $SCRIPT_DIR/environment/shadowtraffic/setup.json ]
  then
    SETUP_FILES+=("setup.json")
  fi

  if [ ${#SETUP_FILES[@]} -eq 0 ]
  then
    echo "No setup files selected for dataset $DATASET"
    exit 111
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
