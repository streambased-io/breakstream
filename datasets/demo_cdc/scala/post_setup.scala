/*
  Move initial CDC orders from hotset (Kafka) to coldset (Iceberg).
  The hotset view of a CDC topic exposes the current state per key (envelope unwrapped).
*/
try {
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.orders USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(10000, kafka_offset)) AS SELECT * FROM isk.hotset.orders;")
} catch {
    case _: Throwable =>
        println("Failed to create coldset.orders from hotset")
        System.exit(1)
}
System.exit(0)
