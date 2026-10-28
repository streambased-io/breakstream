#! /bin/bash
# Waits for roll loop iterations, then checks unrolled_epochs and the cold/union tables.
# UNION_ROLL_INTERVAL_SECONDS (default 300) is also read by the compose part; export a small
# value before start_tests.sh to shorten the wait.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TOPICS="branches transactions customers"
INTERVAL=${UNION_ROLL_INTERVAL_SECONDS:-300}
ITERATIONS=3
# row counts of the static topics in datasets/union_roll/setup.json
declare -A STATIC_ROWS=([branches]=30 [customers]=100000)
# one iteration sleeps INTERVAL, then rolls each topic for at most 600s (curl --max-time)
WAIT_LIMIT=$(( (ITERATIONS + 2) * (INTERVAL + 600 * $(echo $TOPICS | wc -w)) ))

"$SCRIPT_DIR/precheck-spark-connect.sh" || exit 1

# one loop iteration prints one response (or "failed") per topic
roll_results() {
  docker --log-level ERROR compose logs --no-log-prefix union-roll | grep -o '"sealedEpoch"\|roll [a-z_]* failed' | wc -l
}

wait_for_iterations() {
  TARGET=$(( $(roll_results) + ITERATIONS * $(echo $TOPICS | wc -w) ))
  DEADLINE=$(( SECONDS + WAIT_LIMIT ))
  while [ "$(roll_results)" -lt "$TARGET" ]
  do
    if [ "$(docker --log-level ERROR compose ps --status running --services union-roll)" != "union-roll" ]
    then
      echo "union-roll container is not running"
      return 1
    fi
    if [ $SECONDS -ge $DEADLINE ]
    then
      echo "Gave up waiting for $ITERATIONS roll loop iterations"
      return 1
    fi
    sleep 10
  done
}

counts() {
  cat > /tmp/union_roll_counts.scala <<SCALA
def count(sql: String): Long = spark.sql(sql).collect()(0).getLong(0)
def dups(table: String): Long = count(s"SELECT count(*) FROM (SELECT kafka_partition, kafka_offset FROM \$table GROUP BY kafka_partition, kafka_offset HAVING count(*) > 1)")
for (t <- "$TOPICS".split(" ")) {
  val union = count(s"SELECT count(*) FROM isk.union.\`\$t\`")
  val hot = count(s"SELECT count(*) FROM isk.hotset.\`\$t\`")
  val cold = count(s"SELECT count(*) FROM direct.coldset.\`\$t\`")
  val unionDups = dups(s"isk.union.\`\$t\`")
  val coldDups = dups(s"direct.coldset.\`\$t\`")
  println(s"RESULT \$t \$union \$hot \$cold \$unionDups \$coldDups")
}
System.exit(0)
SCALA
  docker --log-level ERROR compose cp /tmp/union_roll_counts.scala spark-iceberg:/tmp/union_roll_counts.scala > /dev/null
  docker --log-level ERROR compose exec -T spark-iceberg sh -c 'cat /tmp/union_roll_counts.scala | spark-shell --driver-memory 4g' | grep '^RESULT '
}

# column N (3 union, 4 hot, 5 cold, 6 union duplicates, 7 cold duplicates) of topic $2 in result set $1
field() {
  echo "$1" | awk -v t="$2" -v n="$3" '$2 == t { print $n }'
}

check_equal() {
  if [ "$2" != "$3" ]
  then
    echo "FAIL: $1: '$2' != '$3'"
    FAILED=1
  fi
}

FAILED=0

wait_for_iterations || exit 1

# (a) every rolled topic is at most one epoch behind
METRICS=$(docker --log-level ERROR compose exec -T union-roll curl -fsS --max-time 30 http://directstream:9464/metrics) || { echo "metrics scrape failed"; exit 1; }
for t in $TOPICS
do
  LINE=$(echo "$METRICS" | grep '^directstream_union_unrolled_epochs' | grep "topic=\"$t\"")
  if [ -z "$LINE" ]
  then
    echo "FAIL: no directstream_union_unrolled_epochs for $t"
    FAILED=1
  elif [ "$(echo "$LINE" | awk '{ if ($NF + 0 > 1) bad = 1 } END { print bad + 0 }')" != "0" ]
  then
    echo "FAIL: unrolled_epochs above 1 for $t: $LINE"
    FAILED=1
  fi
done

# (b) static topics are fully visible through the union before and after the roll, and fully rolled at the end;
# the growing topic has rolled something and its union has no duplicate offsets
FIRST=$(counts)
wait_for_iterations || exit 1
SECOND=$(counts)
for t in $TOPICS
do
  BEFORE=$(field "$FIRST" "$t" 3)
  AFTER=$(field "$SECOND" "$t" 3)
  if [ -z "$BEFORE" ] || [ -z "$AFTER" ] || [ "$AFTER" -lt "$BEFORE" ]
  then
    echo "FAIL: isk.union.$t count went from '$BEFORE' to '$AFTER'"
    FAILED=1
  fi
  check_equal "direct.coldset.$t duplicated (kafka_partition, kafka_offset)" "$(field "$SECOND" "$t" 7)" 0
  check_equal "isk.union.$t duplicated (kafka_partition, kafka_offset)" "$(field "$SECOND" "$t" 6)" 0
done
for t in branches customers
do
  EXPECTED=${STATIC_ROWS[$t]}
  for CHECK in "$FIRST" "$SECOND"
  do
    check_equal "isk.hotset.$t count" "$(field "$CHECK" "$t" 4)" "$EXPECTED"
    check_equal "isk.union.$t count vs isk.hotset.$t" "$(field "$CHECK" "$t" 3)" "$(field "$CHECK" "$t" 4)"
  done
  check_equal "direct.coldset.$t count vs isk.hotset.$t" "$(field "$SECOND" "$t" 5)" "$(field "$SECOND" "$t" 4)"
done
COLD_TRANSACTIONS=$(field "$SECOND" transactions 5)
if [ -z "$COLD_TRANSACTIONS" ] || [ "$COLD_TRANSACTIONS" -le 0 ]
then
  echo "FAIL: direct.coldset.transactions has '$COLD_TRANSACTIONS' rows after the roll"
  FAILED=1
fi

exit $FAILED
