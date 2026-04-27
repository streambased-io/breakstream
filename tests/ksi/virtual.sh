#!/bin/bash

# this just runs scala
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TEST_FILE=test_$RANDOM.scala
SUITE_FILE=suite_$RANDOM.scala
COMMON_FILE=common_$RANDOM.scala
echo "Running virtual_test.scala as $TEST_FILE"
docker --log-level ERROR compose cp $SCRIPT_DIR/virtual_test.scala spark-iceberg:/tmp/$SUITE_FILE
docker --log-level ERROR compose cp $SCRIPT_DIR/../common/scalatest_common.scala spark-iceberg:/tmp/$COMMON_FILE
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/$COMMON_FILE /tmp/$SUITE_FILE > /tmp/$TEST_FILE"
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/$TEST_FILE | spark-shell --driver-memory 8g --repositories https://packages.confluent.io/maven/ --packages org.scalatest:scalatest_2.13:3.2.19,org.apache.kafka:kafka-clients:4.1.0,io.confluent:kafka-avro-serializer:7.5.0"
