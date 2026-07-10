#! /bin/bash
# Source this file to get perf_cases_include(). Used by both the setup-file
# selection in bin/start_tests.sh and the topic drain/restore gating in
# datasets/ksi_reordered_perf/post_setup.sh, so a case selected for setup is
# also the case whose Kafka topic gets drained/restored.

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
      kafka:kafka|kafka:normal-kafka|kafka:reordered_perf_customers_kafka)
        return 0
        ;;
    esac
  done

  return 1
}
