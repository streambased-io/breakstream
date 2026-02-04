import scala.io.AnsiColor._
println(s"${GREEN}\n\nFinally, let's list merged tables. This is the union of topics in Kafka and tables in Iceberg.\n\nAny that exist in both Kafka and Iceberg (e.g. transactions) are intelligently unioned by Streambased.\n${RESET}")
spark.sql("SHOW TABLES IN merged").show()
println("section complete")
