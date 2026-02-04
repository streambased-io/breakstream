import scala.io.AnsiColor._
println(s"${GREEN}\n\nTo show the union, let's confirm the data size of the transactions topic on each view.\n\nFirst the coldset, here we see the transactions data stored in Iceberg\n${RESET}")
spark.sql("SELECT COUNT(*) FROM coldset.transactions").show()
println("section complete")
