#! /bin/bash
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

perf_cases_include() {
  CASE_ID=$1
  RAW_CASES="${REORDERED_PERF_CASES:-ordered,baseline,kafka}"

  if [ -z "$RAW_CASES" ]
  then
    return 0
  fi

  IFS=',' read -ra TOKENS <<< "$RAW_CASES"
  for TOKEN in "${TOKENS[@]}"
  do
    TOKEN=$(echo "$TOKEN" | tr '[:upper:]' '[:lower:]' | xargs)
    if [ "$TOKEN" = "all" ]
    then
      return 0
    fi

    case "$CASE_ID:$TOKEN" in
      ordered:ordered|ordered:ksi-ordered|ordered:ordered-ksi|ordered:reordered_perf_customers_ordered|ordered:${REORDERED_PERF_ORDERED_LABEL:-ksi-ordered-coldset})
        return 0
        ;;
      baseline:baseline|baseline:ksi-baseline|baseline:normal|baseline:reordered|baseline:reordered_perf_customers|baseline:${REORDERED_PERF_BASELINE_LABEL:-ksi-baseline})
        return 0
        ;;
    esac
  done

  return 1
}

echo ""
echo "Copying reordered performance post setup steps to container"
echo ""
docker --log-level ERROR compose cp $SCRIPT_DIR/scala/post_setup.scala spark-iceberg:/tmp/reordered_perf_post_setup.scala 2>&1 >/dev/null

echo ""
echo "Copying populated reordered performance hotsets to coldset using Spark"
echo ""
docker --log-level ERROR compose exec \
  -e REORDERED_PERF_CASES="${REORDERED_PERF_CASES:-ordered,baseline,kafka}" \
  spark-iceberg sh -c 'cat /tmp/reordered_perf_post_setup.scala | spark-shell --driver-memory 8g --conf spark.ui.enabled=false   2>&1 >/dev/null'

echo ""
echo "Draining reordered performance topics from Kafka"
echo ""
if perf_cases_include baseline
then
  docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic reordered_perf_customers --add-config retention.ms=500 2>&1 >/dev/null
  docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic reordered_perf_customers --add-config segment.ms=500 2>&1 >/dev/null
else
  echo "Skipping drain for reordered_perf_customers"
fi
if perf_cases_include ordered
then
  docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic reordered_perf_customers_ordered --add-config retention.ms=500 2>&1 >/dev/null
  docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic reordered_perf_customers_ordered --add-config segment.ms=500 2>&1 >/dev/null
else
  echo "Skipping drain for reordered_perf_customers_ordered"
fi
sleep 3
if perf_cases_include baseline
then
  docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic reordered_perf_customers --add-config retention.ms=604800000 2>&1 >/dev/null
  docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic reordered_perf_customers --add-config segment.ms=604800000 2>&1 >/dev/null
fi
if perf_cases_include ordered
then
  docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic reordered_perf_customers_ordered --add-config retention.ms=604800000 2>&1 >/dev/null
  docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic reordered_perf_customers_ordered --add-config segment.ms=604800000 2>&1 >/dev/null
fi

echo ""
echo "Reordered performance topic post setup complete"
echo ""
