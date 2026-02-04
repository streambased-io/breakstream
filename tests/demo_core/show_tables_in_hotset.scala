import scala.io.AnsiColor._
println(s"${GREEN}\n\nLet's list hostet tables. These correspond exactly to topics in Kafka.\n\nIf new topics are added they will immediately appear here.\n\nThe accounts table exists in Kafka only and has no Iceberg equivalent.\n${RESET}")
spark.sql("SHOW TABLES IN hotset").show()
println("section complete")
