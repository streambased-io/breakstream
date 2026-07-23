/*
Move data from hotset to coldset.
stops and truck_positions are copied; coldset stops enables hot/cold dashboard comparisons.
delivery_control_events are left in hotset only (low volume, always live).
*/
try {
    spark.sql("DROP TABLE IF EXISTS direct.coldset.stops PURGE;")
    spark.sql("DROP TABLE IF EXISTS direct.coldset.truck_positions PURGE;")
    spark.sql("DROP TABLE IF EXISTS direct.coldset.delivery_control_events PURGE;")
    spark.sql("CREATE TABLE direct.coldset.stops USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.stops;")
    spark.sql("CREATE TABLE direct.coldset.truck_positions USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.truck_positions;")
    spark.sql("CREATE TABLE direct.coldset.delivery_control_events USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.delivery_control_events;")
    spark.sql("DROP TABLE IF EXISTS direct.coldset.tax_reporting PURGE;")
    // Create a tax_reporting table with 100 randomly sourced rows
    spark.sql("CREATE TABLE direct.coldset.tax_reporting USING iceberg TBLPROPERTIES('format-version'='2') AS SELECT uuid() as taxId, state, kafka_partition, kafka_offset, kafka_timestamp timestamp FROM direct.coldset.stops ORDER BY kafka_offset LIMIT 100;")
    spark.sql("CREATE NAMESPACE IF NOT EXISTS direct.today;")
} catch {
    case e : Throwable => println("Failed to create coldset from hotset tables")
        e.printStackTrace()
        System.exit(1)
}
System.exit(0)
