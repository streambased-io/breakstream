from subprocess import Popen, PIPE, DEVNULL
import sys
import os
from runner_utils import run_section, stderr_before_spark_ready

# start shell
print("\33[32mWorking with Kafka Clients requires dependencies to be downloaded, Spark will do this now.\33[0m")
input("Press Enter to continue...")

p = Popen(['spark-shell --driver-memory 2g --repositories https://packages.confluent.io/maven/ --packages org.apache.kafka:kafka-clients:4.1.0,io.confluent:kafka-avro-serializer:8.1.0'], stdout=PIPE, stdin=PIPE, stderr=PIPE, text=True, shell=True)

stderr_before_spark_ready(p)
print("\33[32mStarting demo...\33[0m")
input("Press Enter to continue...")

run_section(p,'/tmp/describe_kafka_fetch.scala')
run_section(p,'/tmp/fetch_with_kafka.scala')
run_section(p,'/tmp/describe_ksi_fetch.scala')
run_section(p,'/tmp/fetch_with_ksi.scala')

#  shut down
p.stdin.close()
os._exit(0)