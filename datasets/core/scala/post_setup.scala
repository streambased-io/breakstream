/*
Move data from hotset to coldset
*/
try {
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.branches USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.branches;")
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.transactions USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.transactions;")
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.customers USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.customers;")
} catch {
    case _: Throwable => println("Got an exception exception")
    System.exit(1)
}
System.exit(0)