FROM tabulario/spark-iceberg:3.5.5_1.8.1

RUN curl https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar -o "/opt/spark/jars/hadoop-aws-3.3.4.jar"
RUN curl https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.367/aws-java-sdk-bundle-1.12.367.jar -o "/opt/spark/jars//aws-java-sdk-bundle-1.12.367.jar"

COPY bin/entrypoint.sh /opt/spark/entrypoint.sh
