#! /bin/bash

# this just runs scala
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

DEMO_PT1_FILE=demo_pt1_$RANDOM.scala
echo "Running demo_pt1.scala as $DEMO_PT1_FILE"
echo "About to run demo part 1: the environment"
read -n 1 -s -r -p "Press any key to continue"
docker compose cp $SCRIPT_DIR/demo_pt1.scala spark-iceberg:/tmp/$DEMO_PT1_FILE
docker compose exec spark-iceberg sh -c "cat /tmp/$DEMO_PT1_FILE | spark-shell --driver-memory 8g"
echo "Part 1 complete"
read -n 1 -s -r -p "Press any key to continue"

DEMO_PT2_FILE=demo_pt2_$RANDOM.scala
echo "Running demo_pt2.scala as $DEMO_PT2_FILE"
echo "About to run demo part 2: move hotset to coldset"
read -n 1 -s -r -p "Press any key to continue"
docker compose cp $SCRIPT_DIR/demo_pt2.scala spark-iceberg:/tmp/$DEMO_PT2_FILE
docker compose exec spark-iceberg sh -c "cat /tmp/$DEMO_PT2_FILE | spark-shell --driver-memory 8g"
echo "Part 2 complete"
read -n 1 -s -r -p "Press any key to continue"

DEMO_PT3_FILE=demo_pt3_$RANDOM.scala
echo "Running demo_pt3.scala as $DEMO_PT3_FILE"
echo "About to run demo part 3: ksi"
read -n 1 -s -r -p "Press any key to continue"
docker compose cp $SCRIPT_DIR/demo_pt3.scala spark-iceberg:/tmp/$DEMO_PT3_FILE
docker compose exec spark-iceberg sh -c "cat /tmp/$DEMO_PT3_FILE | spark-shell --driver-memory 8g --packages org.apache.kafka:kafka-clients:4.1.0"
echo "Part 3 complete"
read -n 1 -s -r -p "Press any key to continue"

echo "Demo Complete"
echo ""
