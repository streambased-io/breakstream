import scala.io.AnsiColor._
println(s"${GREEN}\n\nFinally, let's list union views. Each one presents a topic in Kafka together with its table in Iceberg (e.g. transactions) as a single table, intelligently unioned by Streambased.\n${RESET}")
spark.sql("SHOW VIEWS IN union").show()
println("section complete")
