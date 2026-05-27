/*
Move data from hotset to coldset
*/
try {
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.branches USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.branches;")
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.transactions USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.transactions LIMIT 1;")
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.customers USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.customers LIMIT 1;")
    spark.sql("DELETE FROM direct.coldset.transactions;")
    spark.sql("DELETE FROM direct.coldset.customers;")
} catch {
    case e : Throwable => println("Failed to create coldset from hotset tables")
        e.printStackTrace()
        System.exit(1)
}
System.exit(0)