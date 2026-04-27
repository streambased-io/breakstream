import scala.io.AnsiColor._
println(s"${GREEN}\n\nThe orders topic is a CDC stream in Debezium envelope format.\nEach Kafka message contains an 'op' field (c/u/d) and before/after payloads.\n\nI.S.K. automatically unwraps the envelope and presents the topic as a clean Iceberg table.\nLet's describe the schema as seen through the hotset view:\n${RESET}")
spark.sql("DESCRIBE isk.hotset.orders").show(50, false)
println("section complete")
