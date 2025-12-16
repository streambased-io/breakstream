#! /bin/bash

# this just runs scala
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TEST_FILE=test_$RANDOM.scala
SUITE_FILE=suite_$RANDOM.scala
COMMON_FILE=common_$RANDOM.scala
echo "Running test.scala as $TEST_FILE"
docker compose cp $SCRIPT_DIR/test.scala spark-iceberg:/tmp/$SUITE_FILE
docker compose cp $SCRIPT_DIR/../common/scalatest_common.scala spark-iceberg:/tmp/$COMMON_FILE
docker compose exec spark-iceberg sh -c "cat /tmp/$COMMON_FILE /tmp/$SUITE_FILE > /tmp/$TEST_FILE"
docker compose exec spark-iceberg sh -c "cat /tmp/$TEST_FILE | spark-shell --driver-memory 8g --packages org.scalatest:scalatest_2.12:3.0.6,net.liftweb:lift-json_2.12:3.5.0,com.softwaremill.sttp.client4:core_2.12:4.0.13"
