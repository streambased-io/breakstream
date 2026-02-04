import scala.io.AnsiColor._
println(s"${GREEN}\n\nAnd check the latest events added to it. Note the newest 10 events have FraudRiskScore populated - while older ones are rendered with null (events pre-schema change).\n${RESET}")
spark.sql("SELECT * FROM hotset.transactions order by kafka_offset DESC LIMIT 15;").show()
println(s"${GREEN}\n\nNow we can restart ongoing data injection - but using evolved schema.\n${RESET}")
println("section complete")
