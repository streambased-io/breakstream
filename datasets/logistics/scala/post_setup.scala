/*
Create the tax_reporting table and the today namespace. stops, truck_positions and delivery_control_events
reach direct.coldset through the union roll in post_setup.sh.
*/
try {
    spark.sql("DROP TABLE IF EXISTS direct.coldset.tax_reporting PURGE;")
    // Create a tax_reporting table with 100 randomly sourced rows
    spark.sql("CREATE TABLE direct.coldset.tax_reporting USING iceberg TBLPROPERTIES('format-version'='2') AS SELECT uuid() as taxId, state, kafka_partition, kafka_offset, kafka_timestamp timestamp FROM direct.coldset.stops ORDER BY kafka_offset LIMIT 100;")
    spark.sql("CREATE NAMESPACE IF NOT EXISTS direct.today;")
} catch {
    case e : Throwable => println("Failed to create tax_reporting from coldset stops")
        e.printStackTrace()
        System.exit(1)
}
System.exit(0)
