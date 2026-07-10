#! /bin/bash
# Source this file to get topic_exists() and alter_topic_if_exists(). Callers
# typically fire several alter_topic_if_exists calls with `&` and then `wait`
# so independent per-topic config changes run in parallel instead of serially.

topic_exists() {
	local topic=$1
	docker --log-level ERROR compose exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --list | grep -qx "$topic"
}

alter_topic_if_exists() {
	local topic=$1
	local configs=$2
	if topic_exists "$topic"; then
		docker --log-level ERROR compose exec kafka1 kafka-configs --bootstrap-server kafka1:9092 --alter --topic "$topic" --add-config "$configs" 2>&1 >/dev/null
	else
		echo "Skipping config update for missing topic: $topic"
	fi
}

# Polls until a topic's earliest available offset moves past 0, i.e. retention
# has actually deleted the old segments. Kafka's log.retention.check runs on
# an interval (KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS=2000 in this environment),
# so a config change doesn't take effect instantly - a fixed sleep is a guess,
# this is a real wait. Callers can run this for several topics in parallel
# with `&` + `wait`.
wait_for_start_offset() {
	local topic=$1
	local start_offset=0
	while [ "$start_offset" -eq 0 ]
	do
		local offset_shell_out
		offset_shell_out=$(docker --log-level ERROR compose exec kafka1 kafka-get-offsets --time -2 --broker-list kafka1:9092 --topic "$topic")
		start_offset=$(echo "$offset_shell_out" | cut -d':' -f3)
		sleep 1
	done
}
