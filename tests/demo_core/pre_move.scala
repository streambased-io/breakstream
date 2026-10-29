import scala.io.AnsiColor._
println(s"${GREEN}\n\nRight now our data is spread across Kafka and Iceberg. The Iceberg share (coldset) remains static in size but the Kafka share (hotset) is continuously growing.\n\nUnbounded growth like this is often not optimal, Streambased lets you roll data from hotset to coldset with a single call to Hyperstream, which copies it into Iceberg.\n\nLet's start by looking at the current data population in the hotset and coldset for the transactions table\n\nThe union set can't be queried at this point: Kafka now carries the new FraudRiskScore column and the coldset does not have it yet. The roll below adds it to the coldset, after which the union set is queryable again.\n${RESET}")
spark.sql("" +
  "SELECT 'hotset', COUNT(*) FROM isk.hotset.transactions WHERE TransactionTime < now() " +
  "UNION " +
  "SELECT 'coldset', COUNT(*) FROM isk.coldset.transactions WHERE TransactionTime < now() " +
  "").show()
println("section complete")
