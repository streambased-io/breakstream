import scala.io.AnsiColor._
println(s"${GREEN}\n\nRight now our data is spread across Kafka and Iceberg. The Iceberg share (coldset) remains static in size but the Kafka share (hotset) is continuously growing.\n\nUnbounded growth like this is often not optimal, Streambased lets you roll data from hotset to coldset with a single call to Hyperstream, which copies it into Iceberg.\n\nLet's start by looking at the current data population in the hotset and coldset for the transactions table\n\nThe union set already shows the new FraudRiskScore column that Kafka now carries. The coldset does not have it yet, so cold rows read NULL for it until the roll below copies them into the coldset.\n${RESET}")
spark.sql("" +
  "SELECT 'hotset', COUNT(*) FROM isk.hotset.transactions WHERE TransactionTime < now() " +
  "UNION " +
  "SELECT 'coldset', COUNT(*) FROM isk.coldset.transactions WHERE TransactionTime < now() " +
  "UNION " +
  "SELECT 'union', COUNT(*) FROM isk.union.transactions WHERE TransactionTime < now() " +
  "").show()
println("section complete")
