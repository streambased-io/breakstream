/*
Move reordered_perf_customers data from hotset to coldset for performance testing.
*/
try {
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.reordered_perf_customers USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.reordered_perf_customers;")
} catch {
    case e : Throwable => println("Failed to create reordered_perf_customers coldset table from hotset")
        e.printStackTrace()
        System.exit(1)
}
System.exit(0)
