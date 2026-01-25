#! /bin/bash

SLEEP_TIME=20

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASEDIR=$( cd -- "$SCRIPT_DIR/../../" &> /dev/null && pwd )
echo $BASE_DIR

demo_paragraph() {
    if [ "$DEMO_MODE" = "true" ]
    then
      $BASE_DIR/bin/demo_script.sh $1
      echo "Press any key to continue"
      read -s -t$SLEEP_TIME -n1 key
      if [ "$DEBUG_MODE" != "true" ]
      then
        clear
      fi
    fi
}

demo_paragraph 9
demo_paragraph 10

docker --log-level ERROR compose cp $SCRIPT_DIR/demo_pt1.scala spark-iceberg:/tmp/demo_pt1.scala 2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/demo_pt1.scala | spark-shell --driver-memory 8g"

demo_paragraph 11

docker --log-level ERROR compose cp $SCRIPT_DIR/demo_pt2.scala spark-iceberg:/tmp/demo_pt2.scala  2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/demo_pt2.scala | spark-shell --driver-memory 8g"

demo_paragraph 12

docker --log-level ERROR compose cp $SCRIPT_DIR/demo_pt3.scala spark-iceberg:/tmp/demo_pt3.scala  2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/demo_pt3.scala | spark-shell --driver-memory 8g --repositories https://packages.confluent.io/maven/ --packages org.apache.kafka:kafka-clients:4.1.0,io.confluent:kafka-avro-serializer:8.1.0"

demo_paragraph 13