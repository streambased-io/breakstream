import scala.io.AnsiColor._
println(s"${GREEN}\n\nNow let's look at schema evolution - for example addition of a new field.\nNote that background data injection is stopped now - to surface messages easier and inject data with evolved shcema.\n\nLet's describe transactions table on the Hotset projection\n${RESET}")
spark.sql("DESCRIBE hotset.transactions").show()
println("section complete")
