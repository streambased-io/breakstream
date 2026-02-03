import scala.io.AnsiColor._
println(s"${GREEN}\n\nWe begin by describing the databases available. We see:\n\n * hotset - data from Kafka only\n * coldset - data from Iceberg only\n * merged - a hotset and coldset seamlessly unioned by Streambased.\n\nOnly the coldset database physically exists, hotset and merged are virtual databases provided by Streambased I.S.K.\n${RESET}")
spark.sql("SHOW DATABASES").show()
println("section complete")
