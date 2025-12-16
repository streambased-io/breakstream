#! /bin/bash

# this just runs scala
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo "Running demo_pt1.scala"
echo "About to run demo part 1: the environment"
read -n 1 -s -r -p "Press any key to continue"
docker compose cp $SCRIPT_DIR/demo_pt1.scala spark-iceberg:/tmp/demo_pt1.scala
docker compose exec spark-iceberg sh -c "cat /tmp/demo_pt1.scala | spark-shell --driver-memory 8g"
echo "Part 1 complete"
read -n 1 -s -r -p "Press any key to continue"

echo "Running demo_pt2.scala"
echo "About to run demo part 2: move hotset to coldset"
read -n 1 -s -r -p "Press any key to continue"
docker compose cp $SCRIPT_DIR/demo_pt2.scala spark-iceberg:/tmp/demo_pt2.scala
docker compose exec spark-iceberg sh -c "cat /tmp/demo_pt2.scala | spark-shell --driver-memory 8g"
echo "Part 2 complete"
read -n 1 -s -r -p "Press any key to continue"

echo "Running demo_pt3.scala"
echo "About to run demo part 3: ksi"
read -n 1 -s -r -p "Press any key to continue"
docker compose cp $SCRIPT_DIR/demo_pt3.scala spark-iceberg:/tmp/demo_pt3.scala
docker compose exec spark-iceberg sh -c "cat /tmp/demo_pt3.scala | spark-shell --driver-memory 8g --packages org.apache.kafka:kafka-clients:4.1.0"
echo "Part 3 complete"
read -n 1 -s -r -p "Press any key to continue"

echo "Demo Complete"
echo ""
