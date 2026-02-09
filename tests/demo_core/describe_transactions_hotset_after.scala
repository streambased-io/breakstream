import scala.io.AnsiColor._
println(s"${GREEN}\n\nNow that new data is coming into the topic with evolved schema (FraudRiskScore optional field added) - let's describe the table again\n${RESET}")
spark.sql("DESCRIBE hotset.transactions").show()
println("section complete")

