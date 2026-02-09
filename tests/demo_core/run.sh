#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE_DIR=$( cd -- "$SCRIPT_DIR/../../" &> /dev/null && pwd )

demo_paragraph() {
    if [ "$DEMO_MODE" = "true" ]
    then
      ${BASE_DIR}/bin/demo_script.sh $1
      echo "Press any key to continue"
      read -s -t${SLEEP_TIME} -n1 key
      if [ "$DEBUG_MODE" != "true" ]
      then
        clear
      fi
    fi
}

docker --log-level ERROR compose cp $SCRIPT_DIR/../common/runner_utils.py spark-iceberg:/tmp/runner_utils.py 2>&1 >/dev/null
clear

demo_paragraph "test_intro"
demo_paragraph "test_1_header"

docker --log-level ERROR compose cp $SCRIPT_DIR/show_databases.scala spark-iceberg:/tmp/show_databases.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/show_tables_in_coldset.scala spark-iceberg:/tmp/show_tables_in_coldset.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/show_tables_in_hotset.scala spark-iceberg:/tmp/show_tables_in_hotset.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/show_tables_in_merged.scala spark-iceberg:/tmp/show_tables_in_merged.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/count_coldset_transactions.scala spark-iceberg:/tmp/count_coldset_transactions.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/count_hotset_transactions.scala spark-iceberg:/tmp/count_hotset_transactions.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/count_merged_transactions.scala spark-iceberg:/tmp/count_merged_transactions.scala 2>&1 >/dev/null

docker --log-level ERROR compose cp $SCRIPT_DIR/run_demo_1.py spark-iceberg:/tmp/run_demo_1.py 2>&1 >/dev/null
clear
docker --log-level ERROR compose exec spark-iceberg python -i /tmp/run_demo_1.py

clear
docker --log-level ERROR compose down -v shadowtraffic_background 2>&1 >/dev/null
clear
demo_paragraph "test_1a_header"
docker --log-level ERROR compose cp $SCRIPT_DIR/run_demo_1a.py spark-iceberg:/tmp/run_demo_1a.py 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/describe_transactions_hotset.scala spark-iceberg:/tmp/describe_transactions_hotset.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/fetch_transactions_hotset.scala spark-iceberg:/tmp/fetch_transactions_hotset.scala 2>&1 >/dev/null
clear
docker --log-level ERROR compose exec spark-iceberg python -i /tmp/run_demo_1a.py

clear
docker --log-level ERROR compose up shadowtraffic_setup_evolved 2>&1 >/dev/null
clear

docker --log-level ERROR compose cp $SCRIPT_DIR/run_demo_1b.py spark-iceberg:/tmp/run_demo_1b.py 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/describe_transactions_hotset_after.scala spark-iceberg:/tmp/describe_transactions_hotset_after.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/fetch_transactions_hotset_after.scala spark-iceberg:/tmp/fetch_transactions_hotset_after.scala 2>&1 >/dev/null
clear
docker --log-level ERROR compose exec spark-iceberg python -i /tmp/run_demo_1b.py

clear
docker --log-level ERROR compose up -d shadowtraffic_background_evolved 2>&1 >/dev/null
clear
demo_paragraph "test_2_header"

docker --log-level ERROR compose cp $SCRIPT_DIR/pre_move.scala spark-iceberg:/tmp/pre_move.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/alter_table.scala spark-iceberg:/tmp/alter_table.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/move.scala spark-iceberg:/tmp/move.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/post_move.scala spark-iceberg:/tmp/post_move.scala 2>&1 >/dev/null

docker --log-level ERROR compose cp $SCRIPT_DIR/run_demo_2.py spark-iceberg:/tmp/run_demo_2.py 2>&1 >/dev/null
clear
docker --log-level ERROR compose exec spark-iceberg python -i /tmp/run_demo_2.py

clear
demo_paragraph "test_3_header"

docker --log-level ERROR compose cp $SCRIPT_DIR/fetch_with_kafka.scala spark-iceberg:/tmp/fetch_with_kafka.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/describe_kafka_fetch.scala spark-iceberg:/tmp/describe_kafka_fetch.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/describe_ksi_fetch.scala spark-iceberg:/tmp/describe_ksi_fetch.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/fetch_with_ksi.scala spark-iceberg:/tmp/fetch_with_ksi.scala 2>&1 >/dev/null

docker --log-level ERROR compose cp $SCRIPT_DIR/run_demo_3.py spark-iceberg:/tmp/run_demo_3.py 2>&1 >/dev/null
clear
docker --log-level ERROR compose exec spark-iceberg python -i /tmp/run_demo_3.py

clear
demo_paragraph "complete"