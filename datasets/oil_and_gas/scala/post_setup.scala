/*
Create the royalty_reporting table and the today namespace. frac_stages, pump_telemetry and well_control_events
reach direct.coldset through the union roll in post_setup.sh.
*/
try {
    spark.sql("DROP TABLE IF EXISTS direct.coldset.royalty_reporting PURGE;")
    // Create a royalty_reporting table with 100 rows sourced from the archived frac stages
    spark.sql("CREATE TABLE direct.coldset.royalty_reporting USING iceberg TBLPROPERTIES('format-version'='2') AS SELECT uuid() as royaltyId, wellId, stage_number, proppant_placed_lbs, kafka_partition, kafka_offset, kafka_timestamp timestamp FROM direct.coldset.frac_stages ORDER BY kafka_offset LIMIT 100;")
    spark.sql("CREATE NAMESPACE IF NOT EXISTS direct.today;")
} catch {
    case e : Throwable => println("Failed to create royalty_reporting from coldset frac_stages")
        e.printStackTrace()
        System.exit(1)
}
System.exit(0)
