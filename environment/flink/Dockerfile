FROM flink:1.20.1-scala_2.12-java17

ARG MAVEN=https://repo1.maven.org/maven2
ARG ICEBERG_VERSION=1.9.2
ARG FLINK_VERSION=1.20.1
ARG KAFKA_CONNECTOR_VERSION=3.4.0-1.20

# Iceberg (REST catalog + S3FileIO), Kafka/Avro connectors and the Hadoop classes Iceberg's Flink runtime needs
RUN cd /opt/flink/lib && \
    wget -q $MAVEN/org/apache/iceberg/iceberg-flink-runtime-1.20/$ICEBERG_VERSION/iceberg-flink-runtime-1.20-$ICEBERG_VERSION.jar && \
    wget -q $MAVEN/org/apache/iceberg/iceberg-aws-bundle/$ICEBERG_VERSION/iceberg-aws-bundle-$ICEBERG_VERSION.jar && \
    wget -q $MAVEN/org/apache/flink/flink-sql-connector-kafka/$KAFKA_CONNECTOR_VERSION/flink-sql-connector-kafka-$KAFKA_CONNECTOR_VERSION.jar && \
    wget -q $MAVEN/org/apache/flink/flink-sql-avro-confluent-registry/$FLINK_VERSION/flink-sql-avro-confluent-registry-$FLINK_VERSION.jar && \
    wget -q $MAVEN/org/apache/flink/flink-shaded-hadoop-2-uber/2.8.3-10.0/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar

COPY sql /opt/flink/breakstream-sql
COPY sql-client.sh /opt/flink/bin/breakstream-sql-client.sh
RUN chmod +x /opt/flink/bin/breakstream-sql-client.sh
