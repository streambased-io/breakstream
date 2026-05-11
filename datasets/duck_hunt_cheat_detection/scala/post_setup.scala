/*
Move data from hotset to coldset.
All 4 topics are copied so the notebook has a full population history in coldset.
*/
try {
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.shots USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.shots;")
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.gun_positions USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.gun_positions;")
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.control_events USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.control_events;")
    spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.duck_spawns USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.duck_spawns;")
} catch {
    case e : Throwable => println("Failed to create coldset from hotset tables")
        e.printStackTrace()
        System.exit(1)
}
System.exit(0)
