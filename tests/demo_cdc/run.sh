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

# --- setup ---
docker --log-level ERROR compose cp $SCRIPT_DIR/../common/runner_utils.py spark-iceberg:/tmp/runner_utils.py 2>&1 >/dev/null
clear

# --- Part 1: Environment exploration ---
demo_paragraph "cdc_intro"
demo_paragraph "cdc_1_header"

docker --log-level ERROR compose cp $SCRIPT_DIR/show_databases.scala spark-iceberg:/tmp/show_databases.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/describe_orders.scala spark-iceberg:/tmp/describe_orders.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/count_sets.scala spark-iceberg:/tmp/count_sets.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/fetch_sample_orders.scala spark-iceberg:/tmp/fetch_sample_orders.scala 2>&1 >/dev/null

docker --log-level ERROR compose cp $SCRIPT_DIR/run_demo_cdc_1.py spark-iceberg:/tmp/run_demo_cdc_1.py 2>&1 >/dev/null
clear
docker --log-level ERROR compose exec spark-iceberg python -i /tmp/run_demo_cdc_1.py

# --- Part 2: CDC dedup + updates + pre-delete count ---
clear
demo_paragraph "cdc_2_header"

docker --log-level ERROR compose cp $SCRIPT_DIR/count_distinct_check.scala spark-iceberg:/tmp/count_distinct_check.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/show_shipped_orders.scala spark-iceberg:/tmp/show_shipped_orders.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/pre_delete_count.scala spark-iceberg:/tmp/pre_delete_count.scala 2>&1 >/dev/null

docker --log-level ERROR compose cp $SCRIPT_DIR/run_demo_cdc_2.py spark-iceberg:/tmp/run_demo_cdc_2.py 2>&1 >/dev/null
clear
docker --log-level ERROR compose exec spark-iceberg python -i /tmp/run_demo_cdc_2.py

# --- Inject 100 CDC deletes for orders 1-100 ---
clear
demo_paragraph "cdc_delete_header"
docker --log-level ERROR compose down -v shadowtraffic_background 2>&1 >/dev/null
docker --log-level ERROR compose up shadowtraffic_cdc_deletes 2>&1 >/dev/null

# --- Part 2b: Show effect of deletes ---
docker --log-level ERROR compose cp $SCRIPT_DIR/post_delete_count.scala spark-iceberg:/tmp/post_delete_count.scala 2>&1 >/dev/null

docker --log-level ERROR compose cp $SCRIPT_DIR/run_demo_cdc_3.py spark-iceberg:/tmp/run_demo_cdc_3.py 2>&1 >/dev/null
clear
docker --log-level ERROR compose exec spark-iceberg python -i /tmp/run_demo_cdc_3.py

# --- Part 3: Roll to coldset ---
clear
demo_paragraph "cdc_roll_header"

docker --log-level ERROR compose cp $SCRIPT_DIR/pre_roll.scala spark-iceberg:/tmp/pre_roll.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/roll_to_coldset.scala spark-iceberg:/tmp/roll_to_coldset.scala 2>&1 >/dev/null
docker --log-level ERROR compose cp $SCRIPT_DIR/post_roll.scala spark-iceberg:/tmp/post_roll.scala 2>&1 >/dev/null

docker --log-level ERROR compose cp $SCRIPT_DIR/run_demo_cdc_4.py spark-iceberg:/tmp/run_demo_cdc_4.py 2>&1 >/dev/null
clear
docker --log-level ERROR compose exec spark-iceberg python -i /tmp/run_demo_cdc_4.py

clear
demo_paragraph "complete"
