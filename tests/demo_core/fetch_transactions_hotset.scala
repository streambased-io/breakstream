import scala.io.AnsiColor._
println(s"${GREEN}\n\nAnd fetch last few rows as an example.\n${RESET}")
spark.sql("SELECT * FROM hotset.transactions ORDER BY kafka_offset desc limit 10;").show()
println(s"${GREEN}\n\nNow - lets produce some new messages with additional field FraudRiskScore.\n${RESET}")
println("section complete")
