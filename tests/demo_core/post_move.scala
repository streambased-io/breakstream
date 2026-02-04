import scala.io.AnsiColor._
println(s"${GREEN}\n\nAfter transfer the coldset population has increased. Streambased will now serve a larger share of the merged dataset from the coldset\n\nWhy hasn't the hotset population decreased?\n\nStreambased will not explicitly delete data from Kafka, Kafa deletion is handled by the topic retention policy as usual.\n\nThe merged set now contains all of the coldset + the section of hotset that has not yet been transferred to the coldset as you can see below.\n${RESET}")
spark.sql("" +
  "SELECT 'hotset', COUNT(*) FROM isk.hotset.transactions WHERE TransactionTime < now() " +
  "UNION " +
  "SELECT 'coldset', COUNT(*) FROM isk.coldset.transactions WHERE TransactionTime < now() " +
  "UNION " +
  "SELECT 'merged', COUNT(*) FROM isk.merged.transactions WHERE TransactionTime < now() " +
  "").show()
println("section complete")
