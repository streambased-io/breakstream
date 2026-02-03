import scala.io.AnsiColor._
println(s"${GREEN}\n\nNow let's list coldset tables. These correspond exactly to tables in Iceberg.\n\nAgain, if new tables are added they will immediately appear here.\n\nThe branches table exists in Iceberg only and has no Kafka equivalent.\n${RESET}")
spark.sql("SHOW TABLES IN coldset").show()
println("section complete")
