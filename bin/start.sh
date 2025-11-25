#! /bin/bash

die () {
    echo >&2 "$@"
    exit 1
}

# setup and validate
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../
[ "$#" -eq 1 ] || die "1 argument required, $# provided"
ls $SCRIPT_DIR/tests/$1 > /dev/null 2>&1  || die "Test case not found, $1 provided"
SPEC_NAME=$1

# make docker compose
cat $SCRIPT_DIR/environment/header-docker-compose.part.yaml > $SCRIPT_DIR/environment/docker-compose.yaml
for COMPONENT in $(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq .components[] | sed -e 's/"//g')
do
  cat $SCRIPT_DIR/environment/$COMPONENT-docker-compose.part.yaml >> $SCRIPT_DIR/environment/docker-compose.yaml
done

# start services
cd $SCRIPT_DIR/environment
docker-compose up -d

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

  # run setup
  if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
  then
      rm -rf $SCRIPT_DIR/environment/shadowtraffic/*
  fi
  cp -R $SCRIPT_DIR/datasets/$DATASET/* $SCRIPT_DIR/environment/shadowtraffic
  docker-compose up shadowtraffic_setup
  ./shadowtraffic/post_setup.sh
  if (( $? != 0 ))
  then
    # setup failed
    exit 111
  fi
done

# load background datasets
BACKGROUND_DATASET=$(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq .background_dataset | sed -e 's/"//g')
if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
then
    rm -rf $SCRIPT_DIR/environment/shadowtraffic/*
fi
cp -R $SCRIPT_DIR/datasets/$BACKGROUND_DATASET/* $SCRIPT_DIR/environment/shadowtraffic
docker-compose up -d shadowtraffic_background

# run tests
EXITCODE=0
for TEST_NAME in $(cat $SCRIPT_DIR/specs/$SPEC_NAME/spec.json | jq .tests[] | sed -e 's/"//g')
do
  $SCRIPT_DIR/tests/$TEST_NAME/run.sh
  if (( $? != 0 ))
  then
    EXITCODE=1
  fi
done

# tear down
$SCRIPT_DIR/bin/stop.sh

if (( $EXITCODE != 0 ))
then
  echo "TESTS FAILED"
else
  echo "TESTS PASSED"
fi
exit $EXITCODE
