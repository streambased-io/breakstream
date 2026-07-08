#!/bin/bash

# Runs KSI virtual topic tests
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/../common/spark_packages.sh
TEST_FILE=test_$RANDOM.scala
SUITE_FILE=suite_$RANDOM.scala
COMMON_FILE=common_$RANDOM.scala
echo "Running virtual_test.scala as $TEST_FILE"
docker --log-level ERROR compose cp $SCRIPT_DIR/../ksi/virtual_test.scala spark-iceberg:/tmp/$SUITE_FILE
docker --log-level ERROR compose cp $SCRIPT_DIR/../common/scalatest_common.scala spark-iceberg:/tmp/$COMMON_FILE
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/$COMMON_FILE /tmp/$SUITE_FILE > /tmp/$TEST_FILE"
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/$TEST_FILE | spark-shell --driver-memory 8g --repositories $SPARK_REPOSITORIES --packages $SPARK_PACKAGES"
