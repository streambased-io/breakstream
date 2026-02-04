import scala.io.AnsiColor._
println(s"${GREEN}\n\nRight now our data is spread across Kafka and Iceberg. The Iceberg share (coldset) remains static in size but the Kafka share (hotset) is continuously growing.\n\nUnbounded growth like this is often not optimal, Streambased allows you to use your Iceberg engine (in this case Spark) to easily transfer data from hotset to coldset.\n\nLet's start by looking at the current data population in each set for the transactions table\n${RESET}")
spark.sql("" +
  "SELECT 'hotset', COUNT(*) FROM isk.hotset.transactions WHERE TransactionTime < now() " +
  "UNION " +
  "SELECT 'coldset', COUNT(*) FROM isk.coldset.transactions WHERE TransactionTime < now() " +
  "UNION " +
  "SELECT 'merged', COUNT(*) FROM isk.merged.transactions WHERE TransactionTime < now() " +
  "").show()
println("section complete")
