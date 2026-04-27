/*
Move reordered_customers data from hotset to coldset
*/
try {
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.reordered_customers USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.reordered_customers;")
} catch {
    case e : Throwable => println("Failed to create reordered_customers coldset table from hotset")
        e.printStackTrace()
        System.exit(1)
}
System.exit(0)
