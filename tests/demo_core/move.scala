import scala.io.AnsiColor._
println(s"${GREEN}\n\nAnd finally move the data using the INSERT INTO ... SELECT FROM statement ${RESET}")

spark.sql("" +
  "INSERT INTO direct.coldset.transactions " +
  "SELECT * FROM isk.hotset.transactions " +
  "").show()
println("section complete")
