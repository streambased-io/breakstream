#! /bin/bash

# this just runs scala
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo ""
echo "Running demo_pt1.scala"
echo "About to run demo part 1: the environment"
echo ""
read -n 1 -s -r -p "Press any key to continue"

docker --log-level ERROR compose cp $SCRIPT_DIR/demo_pt1.scala spark-iceberg:/tmp/demo_pt1.scala 2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/demo_pt1.scala | spark-shell --driver-memory 8g"

echo ""
echo "Part 1 complete"
echo ""
read -n 1 -s -r -p "Press any key to continue"

echo ""
echo "Running demo_pt2.scala"
echo "About to run demo part 2: move hotset to coldset"
echo ""
read -n 1 -s -r -p "Press any key to continue"

docker --log-level ERROR compose cp $SCRIPT_DIR/demo_pt2.scala spark-iceberg:/tmp/demo_pt2.scala  2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/demo_pt2.scala | spark-shell --driver-memory 8g"

echo ""
echo "Part 2 complete"
echo ""
read -n 1 -s -r -p "Press any key to continue"

echo ""
echo "Running demo_pt3.scala"
echo "About to run demo part 3: ksi"
echo ""
read -n 1 -s -r -p "Press any key to continue"

docker --log-level ERROR compose cp $SCRIPT_DIR/demo_pt3.scala spark-iceberg:/tmp/demo_pt3.scala  2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/demo_pt3.scala | spark-shell --driver-memory 8g --repositories https://packages.confluent.io/maven/ --packages org.apache.kafka:kafka-clients:4.1.0,io.confluent:kafka-avro-serializer:8.1.0"

echo ""
echo "Part 3 complete"
echo ""
read -n 1 -s -r -p "Press any key to continue"

echo ""
echo "Demo Complete"
echo ""
