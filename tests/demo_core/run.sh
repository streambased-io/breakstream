#! /bin/bash

SLEEP_TIME=10

# this just runs scala
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo "In this simulated environment we will perform the following steps:"
echo ""
echo " 1. Use Spark to query a unified dataset composed of Kafka and Iceberg in Iceberg format using I.S.K."
echo " 2. Use Spark to move a hotset of data in Kafka to a coldset in Iceberg"
echo " 3. Run a sample application that consumes a dataset composed of Kafka and Iceberg in Kafka format using K.S.I."
echo ""
echo ""
echo " _          _       _____       _ "
echo "| |        | |     |  __ \     | |"
echo "| |     ___| |_ ___| |  \/ ___ | |"
echo "| |    / _ \ __/ __| | __ / _ \| |"
echo "| |___|  __/ |_\__ \ |_\ \ (_) |_|"
echo "\_____/\___|\__|___/\____/\___/(_)"
echo "                                  "
sleep $SLEEP_TIME
clear

echo ""
echo "                 _                                      _   "
echo "                (_)                                    | |  "
echo "  ___ _ ____   ___ _ __ ___  _ __  _ __ ___   ___ _ __ | |_ "
echo " / _ \ '_ \ \ / / | '__/ _ \| '_ \| '_ \` _ \ / _ \ '_ \| __|"
echo "|  __/ | | \ V /| | | | (_) | | | | | | | | |  __/ | | | |_ "
echo " \___|_| |_|\_/ |_|_|  \___/|_| |_|_| |_| |_|\___|_| |_|\__|"
echo "                                                            "
echo "First let's look at our Iceberg environment, we are using Spark Shell so you can run these exact same commands in your own environment."
sleep $SLEEP_TIME
echo ""

docker --log-level ERROR compose cp $SCRIPT_DIR/demo_pt1.scala spark-iceberg:/tmp/demo_pt1.scala 2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/demo_pt1.scala | spark-shell --driver-memory 8g"

clear
echo "Part 1: Environment Overview Complete"
read -n 1 -s -r -p "Press any key to continue"

echo ""
echo "Running demo_pt2.scala"
echo " _          _                    "
echo "(_)        | |                   "
echo " _  ___ ___| |__   ___ _ __ __ _ "
echo "| |/ __/ _ \ '_ \ / _ \ '__/ _\` |"
echo "| | (_|  __/ |_) |  __/ | | (_| |"
echo "|_|\___\___|_.__/ \___|_|  \__, |"
echo "                            __/ |"
echo "                           |___/ "
echo " _                       _   _             "
echo "(_)                     | | (_)            "
echo " _ _ __   __ _  ___  ___| |_ _  ___  _ __  "
echo "| | '_ \ / _\` |/ _ \/ __| __| |/ _ \| '_ \ "
echo "| | | | | (_| |  __/\__ \ |_| | (_) | | | |"
echo "|_|_| |_|\__, |\___||___/\__|_|\___/|_| |_|"
echo "          __/ |                            "
echo "         |___/                             "
echo "Now let's look at how Streambased can help transfer data from Kafka to Iceberg"
sleep $SLEEP_TIME
echo ""

docker --log-level ERROR compose cp $SCRIPT_DIR/demo_pt2.scala spark-iceberg:/tmp/demo_pt2.scala  2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/demo_pt2.scala | spark-shell --driver-memory 8g"

clear
echo "Part 2: Iceberg Ingestion Complete"
read -n 1 -s -r -p "Press any key to continue"

echo ""
echo "Running demo_pt3.scala"
echo " _____         _                          __     _   __       __ _         "
echo "|_   _|       | |                         \ \   | | / /      / _| |        "
echo "  | |  ___ ___| |__   ___ _ __ __ _   _____\ \  | |/ /  __ _| |_| | ____ _ "
echo "  | | / __/ _ \ '_ \ / _ \ '__/ _\` | |______> > |    \ / _\` |  _| |/ / _\` |"
echo " _| || (_|  __/ |_) |  __/ | | (_| |       / /  | |\  \ (_| | | |   < (_| |"
echo " \___/\___\___|_.__/ \___|_|  \__, |      /_/   \_| \_/\__,_|_| |_|\_\__,_|"
echo "                               __/ |                                       "
echo "                              |___/                                        "

echo "Now let's read Iceberg data from Kafka clients..."
sleep $SLEEP_TIME
echo ""

docker --log-level ERROR compose cp $SCRIPT_DIR/demo_pt3.scala spark-iceberg:/tmp/demo_pt3.scala  2>&1 >/dev/null
docker --log-level ERROR compose exec spark-iceberg sh -c "cat /tmp/demo_pt3.scala | spark-shell --driver-memory 8g --repositories https://packages.confluent.io/maven/ --packages org.apache.kafka:kafka-clients:4.1.0,io.confluent:kafka-avro-serializer:8.1.0"

clear
echo "Part 3: Iceberg -> Kafka Complete"
read -n 1 -s -r -p "Press any key to continue"

echo ""
echo "Demo Complete"
echo ""
