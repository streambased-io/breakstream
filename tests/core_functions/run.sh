#! /bin/bash

# this just runs scala
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TEST_FILE=test_$RANDOM.scala
echo "Running test.scala as $TEST_FILE"
docker-compose cp $SCRIPT_DIR/test.scala spark-iceberg:/tmp/$TEST_FILE
docker-compose exec spark-iceberg sh -c "echo \"System.exit(if (isComplete) 0 else 1)\" | spark-shell --driver-memory 8g -i /tmp/$TEST_FILE --packages org.scalatest:scalatest_2.12:3.0.6"