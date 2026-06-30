#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TEST_FILE=test_$RANDOM.scala
SUITE_FILE=suite_$RANDOM.scala
COMMON_FILE=common_$RANDOM.scala

echo "Running reordered_perf_test.scala as $TEST_FILE"
docker --log-level ERROR compose cp $SCRIPT_DIR/reordered_perf_test.scala spark-iceberg:/tmp/$SUITE_FILE
docker --log-level ERROR compose cp $SCRIPT_DIR/../common/scalatest_common.scala spark-iceberg:/tmp/$COMMON_FILE
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/$COMMON_FILE /tmp/$SUITE_FILE > /tmp/$TEST_FILE"
docker --log-level ERROR compose exec \
  -e REORDERED_PERF_TARGET_RECORDS="${REORDERED_PERF_TARGET_RECORDS:-1000000}" \
  -e REORDERED_PERF_KSI_MAX_POLL_RECORDS="${REORDERED_PERF_KSI_MAX_POLL_RECORDS:-50000}" \
  -e REORDERED_PERF_KAFKA_MAX_POLL_RECORDS="${REORDERED_PERF_KAFKA_MAX_POLL_RECORDS:-200}" \
  -e REORDERED_PERF_POLL_TIMEOUT_SECONDS="${REORDERED_PERF_POLL_TIMEOUT_SECONDS:-30}" \
  -e REORDERED_PERF_EMPTY_POLLS="${REORDERED_PERF_EMPTY_POLLS:-3}" \
  -e REORDERED_PERF_CASES="${REORDERED_PERF_CASES:-ordered,baseline,kafka}" \
  -e REORDERED_PERF_BASELINE_LABEL="${REORDERED_PERF_BASELINE_LABEL:-ksi-baseline}" \
  -e REORDERED_PERF_ORDERED_LABEL="${REORDERED_PERF_ORDERED_LABEL:-ksi-ordered-coldset}" \
  spark-iceberg sh -c "cat /tmp/$TEST_FILE | spark-shell --driver-memory 8g --repositories https://packages.confluent.io/maven/ --packages org.scalatest:scalatest_2.13:3.2.19,org.apache.kafka:kafka-clients:4.1.0,io.confluent:kafka-avro-serializer:7.5.0"
