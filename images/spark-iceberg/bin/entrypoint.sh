#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

## make conf
cat /opt/spark/conf/spark-defaults-orig.conf | sed -e "s/{{DIRECTSTREAM_CATALOG_URI}}/$DIRECTSTREAM_CATALOG_URI/g" | sed -e "s/{{DIRECTSTREAM_S3_ENDPOINT}}/$DIRECTSTREAM_S3_ENDPOINT/g" > /opt/spark/conf/spark-defaults.conf

## notebook dependencies
pip install grpcio google protobuf grpcio-status

# db dirs
mkdir -p /opt/derby
chmod 777 /opt/derby

start-master.sh -p 7077
start-worker.sh spark://spark-iceberg:7077
start-history-server.sh --conf "-spark.driver.extraJavaOptions=-Dderby.system.home=/opt/derby"

# thrift
start-thriftserver.sh

## start spark-connect
start-connect-server.sh --packages org.apache.spark:spark-connect_2.12:3.5.5 --master spark://spark-iceberg:7077 --executor-memory 8g

### sleep til killed
sleep infinity

