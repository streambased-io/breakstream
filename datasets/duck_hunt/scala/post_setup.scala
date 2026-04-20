/*
Move data from hotset to coldset.
shots and gun_positions are copied; coldset shots enables hot/cold dashboard comparisons.
control_events are left in hotset only (low volume, always live).
*/
try {
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.shots USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.shots;")
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.gun_positions USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.gun_positions;")
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.control_events USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.control_events;")
} catch {
    case e : Throwable => println("Failed to create coldset from hotset tables")
        e.printStackTrace()
        System.exit(1)
}
System.exit(0)
