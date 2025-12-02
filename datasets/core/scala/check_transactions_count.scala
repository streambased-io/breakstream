import scala.util.control.Breaks._

var count = -1L;
val tries : Range = 1 to 20;
breakable { for (t <- tries) {
    Thread.sleep(5000)
    println("Checking transactions topic has been drained. Attempt: " + t)
    val ret = spark.sql("SELECT COUNT(*) as count FROM isk.hotset.transactions;")
    count = ret.take(1)(0)(0).asInstanceOf[Long]
    if (count == 0) System.exit(0)
} }
System.exit(1)