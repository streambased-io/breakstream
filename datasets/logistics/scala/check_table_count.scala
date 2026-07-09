import scala.util.control.Breaks._

// give the log cleaner a head start (retention check runs every 2s, see
// KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS in kafka-docker-compose.part.yaml)
Thread.sleep(3000)

val tables = Seq("stops", "truck_positions", "delivery_control_events")
val tries : Range = 1 to 15;

breakable { for (t <- tries) {
    Thread.sleep(1500)
    println("Checking tables have been drained. Attempt: " + t)
    val counts = tables.map { table =>
        val ret = spark.sql(s"SELECT COUNT(*) as count FROM isk.hotset.$table;")
        ret.take(1)(0)(0).asInstanceOf[Long]
    }
    println("Counts: " + tables.zip(counts).map { case (t, c) => s"$t=$c" }.mkString(", "))
    if (counts.forall(_ == 0)) System.exit(0)
} }
System.exit(1)
