#!/bin/bash

# this just runs scala
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PACKAGES="org.scalatest:scalatest_2.13:3.2.19,net.liftweb:lift-json_2.13:3.5.0"

# Step 1: Run SUBSTRING transformer tests
echo "Running SUBSTRING transformer tests"
SUBSTR_TEST_FILE=test_$RANDOM.scala
SUBSTR_SUITE_FILE=suite_$RANDOM.scala
COMMON_FILE=common_$RANDOM.scala
CLIENT_FILE=client_$RANDOM.scala
docker --log-level ERROR compose cp $SCRIPT_DIR/test_substring.scala spark-iceberg:/tmp/$SUBSTR_SUITE_FILE
docker --log-level ERROR compose cp $SCRIPT_DIR/../common/scalatest_common.scala spark-iceberg:/tmp/$COMMON_FILE
docker --log-level ERROR compose cp $SCRIPT_DIR/../common/hyperstream_client.scala spark-iceberg:/tmp/$CLIENT_FILE
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/$COMMON_FILE /tmp/$CLIENT_FILE /tmp/$SUBSTR_SUITE_FILE > /tmp/$SUBSTR_TEST_FILE"
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/$SUBSTR_TEST_FILE | spark-shell --driver-memory 8g --conf spark.ui.enabled=false --packages $PACKAGES"
if [ $? -ne 0 ]; then
  echo "SUBSTRING transformer tests FAILED"
  exit 1
fi

# Step 2: Reset hyperstream container
echo "Resetting hyperstream container"
docker --log-level ERROR compose restart hyperstream
sleep 10

# Step 3: Run remaining tests (UPPER, UPPER(TRIM), Plain Field)
echo "Running remaining hyperstream tests"
TEST_FILE=test_$RANDOM.scala
SUITE_FILE=suite_$RANDOM.scala
COMMON_FILE=common_$RANDOM.scala
CLIENT_FILE=client_$RANDOM.scala
docker --log-level ERROR compose cp $SCRIPT_DIR/test.scala spark-iceberg:/tmp/$SUITE_FILE
docker --log-level ERROR compose cp $SCRIPT_DIR/../common/scalatest_common.scala spark-iceberg:/tmp/$COMMON_FILE
docker --log-level ERROR compose cp $SCRIPT_DIR/../common/hyperstream_client.scala spark-iceberg:/tmp/$CLIENT_FILE
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/$COMMON_FILE /tmp/$CLIENT_FILE /tmp/$SUITE_FILE > /tmp/$TEST_FILE"
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/$TEST_FILE | spark-shell --driver-memory 8g --conf spark.ui.enabled=false --packages $PACKAGES"
