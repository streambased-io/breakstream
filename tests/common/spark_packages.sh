#! /bin/bash
# Shared package/repository set for every test's spark-shell invocation.
# There's no conflict between the per-test subsets that used to be passed
# individually, so all tests just pull the union.

SPARK_REPOSITORIES="https://packages.confluent.io/maven/"
SPARK_PACKAGES="org.scalatest:scalatest_2.13:3.2.19,org.apache.kafka:kafka-clients:4.1.0,io.confluent:kafka-avro-serializer:7.5.0,net.liftweb:lift-json_2.13:3.5.0"
