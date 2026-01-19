#! /bin/bash

SLEEP_TIME=10

die () {
    echo >&2 "$@"
    exit 1
}

# setup and validate
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../
if [ "$#" -eq 1 ]
then
  ls $SCRIPT_DIR/specs/$1 > /dev/null 2>&1  || die "Test case not found, $1 provided"
  SPEC_NAME=$1
else
  SPEC_NAME="demo_core"
fi

if [[ $SPEC_NAME == demo_* ]]
then

  echo "______                _        _                            "
  echo "| ___ \              | |      | |                           "
  echo "| |_/ /_ __ ___  __ _| | _____| |_ _ __ ___  __ _ _ __ ___  "
  echo "| ___ \ '__/ _ \/ _\` | |/ / __| __| '__/ _ \/ _\` | '_ \` _ \ "
  echo "| |_/ / | |  __/ (_| |   <\__ \ |_| | |  __/ (_| | | | | | |"
  echo "\____/|_|  \___|\__,_|_|\_\___/\__|_|  \___|\__,_|_| |_| |_|"
  echo "                                                            "
  echo "                                                            "
  echo "Welcome to BreakStream, the interactive Streambased testing environment..."
  sleep $SLEEP_TIME
  clear

  echo "Streambased combines real-time data in Kafka with lake data in Iceberg to provide a unified view of your data."
  echo "┌────────────────────────────────────────────────────────────────────────────┐"
  echo "│                              APPLICATIONS                                  │"
  echo "│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │"
  echo "│  │  REST / UI   │  │ Spark/Trino  │  │ Kafka Apps   │  │ Data Science │    │"
  echo "│  │ (Slipstream) │  │ (Iceberg)    │  │ (Consumers)  │  │ (Notebooks)  │    │"
  echo "│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │"
  echo "└─────────┼─────────────────┼─────────────────┼─────────────────┼────────────┘"
  echo "          │                 │                 │                 │"
  echo "          ▼                 ▼                 ▼                 ▼"
  echo "┌─────────────────────────────────────────────────────────────────────────────┐"
  echo "│                                                                             │"
  echo "│                          STREAMBASED LAYER                                  │"
  echo "│                                                                             │"
  echo "└─────────────────────────────────────────────────────────────────────────────┘"
  echo "                              │"
  echo "        ┌─────────────────────┴─────────────────────┐"
  echo "        │                                           │"
  echo "        ▼                                           ▼"
  echo "┌───────────────────────────────┐   ┌───────────────────────────────┐"
  echo "│           HOTSET              │   │          COLDSET              │"
  echo "│                               │   │                               │"
  echo "│  ┌─────────────────────────┐  │   │  ┌─────────────────────────┐  │"
  echo "│  │        Kafka            │  │   │  │        Iceberg          │  │"
  echo "│  │                         │  │   │  │                         │  │"
  echo "│  └─────────────────────────┘  │   │  └─────────────────────────┘  │"
  echo "│                               │   │                               │"
  echo "└───────────────────────────────┘   └───────────────────────────────┘"
  sleep $SLEEP_TIME
  clear

  echo "In this environment, we will set up the typical components of a modern data architecture:"
  echo ""
  echo " * Kafka - real-time data"
  echo " * Schema Registry - governance"
  echo " * Iceberg - long term data storage"
  echo " * Spark - an industry standard data processor"
  echo ""
  echo "In addition we will deploy Streambased components:"
  echo ""
  echo " * I.S.K. - a service to surface Kafka data in Iceberg format"
  echo " * K.S.I. - a service that surafces Iceberg data in Kafka format"
  sleep $SLEEP_TIME
  clear

  echo "First let's get set up, to populate our demo environment we will:"
  echo ""
  echo " 1. Generate a sample dataset into Kafka"
  echo " 2. Use I.S.K. to move this initial population from Kafka to Iceberg (hotset to coldset)"
  echo " 3. Start continuous data generation into Kafka"
  echo ""
  echo ""
  echo " _          _       _____       _ "
  echo "| |        | |     |  __ \     | |"
  echo "| |     ___| |_ ___| |  \/ ___ | |"
  echo "| |    / _ \ __/ __| | __ / _ \| |"
  echo "| |___|  __/ |_\__ \ |_\ \ (_) |_|"
  echo "\_____/\___|\__|___/\____/\___/(_)"
  echo "                                  "
  sleep $SLEEP_TIME
  clear

fi



# make docker compose
cat $SCRIPT_DIR/environment/header-docker-compose.part.yaml > $SCRIPT_DIR/environment/docker-compose.yaml
for COMPONENT in $(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq .components[] | sed -e 's/"//g')
do
  cat $SCRIPT_DIR/environment/$COMPONENT-docker-compose.part.yaml >> $SCRIPT_DIR/environment/docker-compose.yaml
done

# start services
cd $SCRIPT_DIR/environment
echo "Starting environment for spec $SPEC_NAME"
docker --log-level ERROR compose up -d
clear

# prepare shadowtraffic
if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
then
    rm -rf $SCRIPT_DIR/environment/shadowtraffic
fi
mkdir -p $SCRIPT_DIR/environment/shadowtraffic
curl  https://raw.githubusercontent.com/ShadowTraffic/shadowtraffic-examples/refs/heads/master/free-trial-license.env > $SCRIPT_DIR/environment/shadowtraffic_license.env

# load setup datasets
for DATASET in $(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq .setup_datasets[] | sed -e 's/"//g')
do

  echo "Setting up dataset $DATASET"

  # run setup
  if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
  then
      rm -rf $SCRIPT_DIR/environment/shadowtraffic/*
  fi
  cp -R $SCRIPT_DIR/datasets/$DATASET/* $SCRIPT_DIR/environment/shadowtraffic
  if [ -f $SCRIPT_DIR/environment/shadowtraffic/setup.json ]
  then

    if [[ $SPEC_NAME == demo_* ]]
    then
      echo "Step 1: Loading an initial population into Kafka"
      echo ""
      echo "______      _              __     _   __       __ _         "
      echo "|  _  \    | |             \ \   | | / /      / _| |        "
      echo "| | | |__ _| |_ __ _   _____\ \  | |/ /  __ _| |_| | ____ _ "
      echo "| | | / _\` | __/ _\` | |______> > |    \ / _\` |  _| |/ / _\` |"
      echo "| |/ / (_| | || (_| |       / /  | |\  \ (_| | | |   < (_| |"
      echo "|___/ \__,_|\__\__,_|      /_/   \_| \_/\__,_|_| |_|\_\__,_|"
      echo "                                                            "
      sleep 10
      clear
    fi
    docker --log-level ERROR compose up -d shadowtraffic_setup
  fi
  while [ "$(docker --log-level ERROR compose ps | grep shadowtraffic_setup | wc -l)" = "1" ]
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

  echo "Dataset $DATASET loaded to Kafka topics, running post setup steps (this may take several minutes)..."
  if [ -f $SCRIPT_DIR/environment/shadowtraffic/post_setup.sh ]
  then
    if [[ $SPEC_NAME == demo_* ]]
        then
          echo "Step 2: Using Spark and Streambased to move the initial population from Kafka to Iceberg"
          echo ""
          echo " _   __       __ _               __     _____         _                    "
          echo "| | / /      / _| |              \ \   |_   _|       | |                   "
          echo "| |/ /  __ _| |_| | ____ _   _____\ \    | |  ___ ___| |__   ___ _ __ __ _ "
          echo "|    \ / _\` |  _| |/ / _\` | |______> >   | | / __/ _ \ '_ \ / _ \ '__/ _\` |"
          echo "| |\  \ (_| | | |   < (_| |       / /   _| || (_|  __/ |_) |  __/ | | (_| |"
          echo "\_| \_/\__,_|_| |_|\_\__,_|      /_/    \___/\___\___|_.__/ \___|_|  \__, |"
          echo "                                                                      __/ |"
          echo "                                                                     |___/ "
          sleep 10
          clear
        fi
    $SCRIPT_DIR/environment/shadowtraffic/post_setup.sh
  fi
  echo "Post setup steps for dataset $DATASET completed."
  if (( $? != 0 ))
  then
    # setup failed
    echo "FAILED TO SETUP DATASET $DATASET: POST SETUP STEPS FAILED"
    exit 113
  fi
done

# load background datasets
sleep 3
clear
echo "Starting background dataset"
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
    if [[ $SPEC_NAME == demo_* ]]
    then
      echo "Step 3: Starting continuous background data generation into Kafka"
      echo ""
      echo " _   _                ______      _              __     _   __       __ _         "
      echo "| \ | |               |  _  \    | |             \ \   | | / /      / _| |        "
      echo "|  \| | _____      __ | | | |__ _| |_ __ _   _____\ \  | |/ /  __ _| |_| | ____ _ "
      echo "| . \` |/ _ \ \ /\ / / | | | / _\` | __/ _\` | |______> > |    \ / _\` |  _| |/ / _\` |"
      echo "| |\  |  __/\ V  V /  | |/ / (_| | || (_| |       / /  | |\  \ (_| | | |   < (_| |"
      echo "\_| \_/\___| \_/\_/   |___/ \__,_|\__\__,_|      /_/   \_| \_/\__,_|_| |_|\_\__,_|"
      echo ""
      sleep 10
      clear
    fi
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
  echo "Running TEST: $TEST_NAME"
  $SCRIPT_DIR/tests/$TEST_NAME/run.sh
  if (( $? != 0 ))
  then
    echo "TEST $TEST_NAME FAILED"
    export EXITCODE=114
  fi
done

# tear down
if [[ $SPEC_NAME == demo_* ]]
then
  echo "Demo spec detected, preserving environment for inspection. Run ./bin/stop.sh to stop the environment."
  exit $EXITCODE
else
  $SCRIPT_DIR/bin/stop.sh

  if (( $EXITCODE != 0 ))
  then
    echo "TESTS FAILED"
  else
    echo "TESTS PASSED"
  fi
  exit $EXITCODE
fi
