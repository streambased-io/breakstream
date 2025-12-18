#! /bin/bash

# this just runs scala
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

INTRO_FILE=introduction.scala
docker compose cp $SCRIPT_DIR/introduction.scala spark-iceberg:/tmp/$INTRO_FILE
docker compose exec -it spark-iceberg spark-shell --driver-memory 8g -i /tmp/$INTRO_FILE
echo ""
read -n 1 -s -r -p "Press any button to continue to part 1: see a unified view of your data"
echo ""

SEE_YOUR_DATA_FILE=see_your_data.scala
docker compose cp $SCRIPT_DIR/see_your_data/see_your_data.scala spark-iceberg:/tmp/$SEE_YOUR_DATA_FILE
docker compose exec -it spark-iceberg spark-shell --driver-memory 8g -i /tmp/$SEE_YOUR_DATA_FILE
echo ""
read -n 1 -s -r -p "Press any button to continue to part 2: query your data"
echo ""


QUERY_YOUR_DATA_FILE=query_your_data.scala
docker compose cp $SCRIPT_DIR/query_data/query_your_data.scala spark-iceberg:/tmp/$QUERY_YOUR_DATA_FILE
docker compose exec -it spark-iceberg spark-shell --driver-memory 8g -i /tmp/$QUERY_YOUR_DATA_FILE
echo ""
read -n 1 -s -r -p "Press any button to continue and view the hotset tables"
echo ""

HOTSET_SHOW_TABLES_FILE=hotset_show_tables.scala
docker compose cp $SCRIPT_DIR/query_data/hotset_show_tables.scala spark-iceberg:/tmp/$HOTSET_SHOW_TABLES_FILE
docker compose exec -it spark-iceberg spark-shell --driver-memory 8g -i /tmp/$HOTSET_SHOW_TABLES_FILE
echo ""
read -n 1 -s -r -p "Press any button to continue and select 5 messages from the transactions table"
echo ""

HOTSET_SELECT_5_FILE=hotset_select_5.scala
docker compose cp $SCRIPT_DIR/query_data/hotset_select_5.scala spark-iceberg:/tmp/$HOTSET_SELECT_5_FILE
docker compose exec -it spark-iceberg spark-shell --driver-memory 8g -i /tmp/$HOTSET_SELECT_5_FILE
echo ""
read -n 1 -s -r -p "Press any button to continue and describe the schema for the transactions table"
echo ""

HOTSET_DESCRIBE_SCHEMA_FILE=hotset_describe_schema.scala
docker compose cp $SCRIPT_DIR/query_data/hotset_describe_schema.scala spark-iceberg:/tmp/$HOTSET_DESCRIBE_SCHEMA_FILE
docker compose exec -it spark-iceberg spark-shell --driver-memory 8g -i /tmp/$HOTSET_DESCRIBE_SCHEMA_FILE
echo ""
read -n 1 -s -r -p "Press any button to continue and view the coldset tables"
echo ""

COLDSET_SHOW_TABLES_FILE=coldset_show_tables.scala
docker compose cp $SCRIPT_DIR/query_data/coldset_show_tables.scala spark-iceberg:/tmp/$COLDSET_SHOW_TABLES_FILE
docker compose exec -it spark-iceberg spark-shell --driver-memory 8g -i /tmp/$COLDSET_SHOW_TABLES_FILE
echo ""
read -n 1 -s -r -p "Press any button to continue and view the merged data"
echo ""

MERGED_SHOW_TABLES_FILE=merged_show_tables.scala
docker compose cp $SCRIPT_DIR/query_data/merged_show_tables.scala spark-iceberg:/tmp/$MERGED_SHOW_TABLES_FILE
docker compose exec -it spark-iceberg spark-shell --driver-memory 8g -i /tmp/$MERGED_SHOW_TABLES_FILE
echo ""
read -n 1 -s -r -p "Press any button to continue and view the merged message count"
echo ""

MERGED_SHOW_MESSAGE_COUNT_FILE=merged_show_message_count.scala
docker compose cp $SCRIPT_DIR/query_data/merged_show_message_count.scala spark-iceberg:/tmp/$MERGED_SHOW_MESSAGE_COUNT_FILE
docker compose exec -it spark-iceberg spark-shell --driver-memory 8g -i /tmp/$MERGED_SHOW_MESSAGE_COUNT_FILE
echo ""
read -n 1 -s -r -p "Press any button to continue and view 10 rows from the merged table"
echo ""

MERGED_SELECT_10_FILE=merged_select_10.scala
docker compose cp $SCRIPT_DIR/query_data/merged_select_10.scala spark-iceberg:/tmp/$MERGED_SELECT_10_FILEE
docker compose exec -it spark-iceberg spark-shell --driver-memory 8g -i /tmp/$MERGED_SELECT_10_FILE
echo ""
read -n 1 -s -r -p "Press any button to continue to move your data"
echo ""


read -n 1 -s -r -p "End of paragraphs added so far"

DEMO_PT2_FILE=demo_pt2.scala
echo "Running demo_pt2.scala as $DEMO_PT2_FILE"
echo "About to run demo part 2: move hotset to coldset"
read -n 1 -s -r -p "Press any key to continue"
docker compose cp $SCRIPT_DIR/demo_pt2.scala spark-iceberg:/tmp/demo_pt2.scala
docker compose exec spark-iceberg sh -c "cat /tmp/demo_pt2.scala | spark-shell --driver-memory 8g"
echo "Part 2 complete"
read -n 1 -s -r -p "Press any key to continue"

DEMO_PT3_FILE=demo_pt3.scala
echo "Running demo_pt3.scala as $DEMO_PT3_FILE"
echo "About to run demo part 3: ksi"
read -n 1 -s -r -p "Press any key to continue"
docker compose cp $SCRIPT_DIR/demo_pt3.scala spark-iceberg:/tmp/demo_pt3.scala
docker compose exec spark-iceberg sh -c "cat /tmp/demo_pt3.scala | spark-shell --driver-memory 8g --repositories https://packages.confluent.io/maven/ --packages org.apache.kafka:kafka-clients:4.1.0,io.confluent:kafka-avro-serializer:8.1.0"
echo "Part 3 complete"
read -n 1 -s -r -p "Press any key to continue"

echo "Demo Complete"
echo ""
