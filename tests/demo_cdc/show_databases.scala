import scala.io.AnsiColor._
println(s"${GREEN}\n\nLet's begin by exploring the Iceberg databases available.\n\nStreambased exposes three views:\n\n  * hotset  - the live CDC stream from Kafka, showing the current state per key\n  * coldset - historical order data stored in Iceberg\n  * merged  - a unified view combining both, always showing the latest state\n${RESET}")
spark.sql("SHOW DATABASES").show()
println("section complete")
