/*
Move reordered performance topics from hotset to coldset for performance testing.
*/
try {
    val rawCases = sys.env.getOrElse("REORDERED_PERF_CASES", "ordered,baseline,kafka")
    val tokens = rawCases.split(",").map(_.trim.toLowerCase).filter(_.nonEmpty).toSet
    def includesCase(caseId: String): Boolean = {
        tokens.isEmpty ||
        tokens.contains("all") ||
        (caseId == "ordered" && (tokens.contains("ordered") || tokens.contains("ksi-ordered") || tokens.contains("ordered-ksi") || tokens.contains("reordered_perf_customers_ordered"))) ||
        (caseId == "baseline" && (tokens.contains("baseline") || tokens.contains("ksi-baseline") || tokens.contains("normal") || tokens.contains("reordered") || tokens.contains("reordered_perf_customers")))
    }

    spark.sql("CREATE NAMESPACE IF NOT EXISTS direct.coldset")

    if (includesCase("baseline")) {
        spark.sql("DROP TABLE IF EXISTS direct.coldset.reordered_perf_customers")
        spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.reordered_perf_customers USING iceberg TBLPROPERTIES('format-version'='2') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.reordered_perf_customers")
    } else {
        println(s"Skipping direct.coldset.reordered_perf_customers for REORDERED_PERF_CASES=$rawCases")
    }

    if (includesCase("ordered")) {
        spark.sql("DROP TABLE IF EXISTS direct.coldset.reordered_perf_customers_ordered")
        spark.sql("CREATE TABLE IF NOT EXISTS direct.coldset.reordered_perf_customers_ordered USING iceberg TBLPROPERTIES('format-version'='2', 'write.distribution-mode'='range') PARTITIONED BY (kafka_partition, truncate(1000, kafka_offset)) AS SELECT * FROM isk.hotset.reordered_perf_customers_ordered ORDER BY kafka_timestamp, kafka_partition, kafka_offset")
    } else {
        println(s"Skipping direct.coldset.reordered_perf_customers_ordered for REORDERED_PERF_CASES=$rawCases")
    }

    spark.sql("USE direct.coldset")
    if (includesCase("baseline")) {
        spark.sql("SELECT COUNT(*) FROM direct.coldset.reordered_perf_customers").show(false)
    }
    if (includesCase("ordered")) {
        spark.sql("SELECT COUNT(*) FROM direct.coldset.reordered_perf_customers_ordered").show(false)
    }
} catch {
    case e : Throwable => println("Failed to create reordered performance coldset tables from hotset")
        e.printStackTrace()
        System.exit(1)
}
System.exit(0)
