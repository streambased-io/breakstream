import scala.io.AnsiColor._
println(s"${GREEN}\n\nNow the data size of the transactions topic in the hotset.\n\nHere we see the transactions data stored in Kafka\n${RESET}")
spark.sql("SELECT COUNT(*) FROM hotset.transactions").show()
println("section complete")
