import scala.io.AnsiColor._
println(s"${GREEN}\n\nWe begin by describing the databases available. We see:\n\n * hotset - data from Kafka only\n * coldset - data from Iceberg only\n * union - the coldset plus the part of the hotset that has not been rolled into it yet, seamlessly unioned by Streambased.\n\nOnly the coldset database physically exists, hotset and union are virtual databases provided by Streambased I.S.K.\n${RESET}")
spark.sql("SHOW DATABASES").show()
println("section complete")
