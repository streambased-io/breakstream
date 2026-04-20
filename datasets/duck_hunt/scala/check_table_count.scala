import scala.util.control.Breaks._

// give it a head start
Thread.sleep(20000)

val tables = Seq("shots", "gun_positions", "control_events")
val tries : Range = 1 to 10;

breakable { for (t <- tries) {
    Thread.sleep(5000)
    println("Checking tables have been drained. Attempt: " + t)
    val counts = tables.map { table =>
        val ret = spark.sql(s"SELECT COUNT(*) as count FROM isk.hotset.$table;")
        ret.take(1)(0)(0).asInstanceOf[Long]
    }
    println("Counts: " + tables.zip(counts).map { case (t, c) => s"$t=$c" }.mkString(", "))
    if (counts.forall(_ == 0)) System.exit(0)
} }
System.exit(1)
