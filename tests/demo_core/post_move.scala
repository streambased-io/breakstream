import scala.io.AnsiColor._
println(s"${GREEN}\n\nAfter the roll the coldset population has increased. Streambased will now serve a larger share of the union dataset from the coldset\n\nWhy hasn't the hotset population decreased?\n\nStreambased will not explicitly delete data from Kafka, Kafa deletion is handled by the topic retention policy as usual.\n\nThe union set now contains all of the coldset + the section of hotset that has not yet been transferred to the coldset as you can see below.\n${RESET}")
spark.sql("" +
  "SELECT 'hotset', COUNT(*) FROM isk.hotset.transactions WHERE TransactionTime < now() " +
  "UNION " +
  "SELECT 'coldset', COUNT(*) FROM isk.coldset.transactions WHERE TransactionTime < now() " +
  "UNION " +
  "SELECT 'union', COUNT(*) FROM isk.union.transactions WHERE TransactionTime < now() " +
  "").show()
println(s"${GREEN}\n\nThe roll also evolved the coldset schema to match the Kafka schema evolution, here is the new FraudRiskScore column:\n${RESET}")
spark.sql("DESCRIBE direct.coldset.transactions").show()
println("section complete")
