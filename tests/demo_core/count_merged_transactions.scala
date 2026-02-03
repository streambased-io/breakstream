import scala.io.AnsiColor._
println(s"${GREEN}\n\nAnd now the data size of the transactions topic in the merged set.\n\nThis is a seamless combination of Kafka and Iceberg data.\n\nWhy doesn't the merged size equal hotset + coldset?\n\nStreambased garuntees that any queries will run against the latest data available at the time of query execution. As the hotset is being constantly written to, more data is available in it now than there was when we queried the hotset individually\n${RESET}")
spark.sql("SELECT COUNT(*) FROM merged.transactions").show()
println("section complete")
