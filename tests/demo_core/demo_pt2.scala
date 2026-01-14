import scala.io.AnsiColor._

val sleepTime = 15000

println(s"${GREEN}\n\nRight now our data is spread across Kafka and Iceberg. The Iceberg share (coldset) remains static in size but the Kafka share (hotset) is continuously growing.\n\nUnbounded growth like this is often not optimal, Streambased allows you to use your Iceberg engine (in this case Spark) to easily transfer data from hotset to coldset.\n\nLet's start by looking at the current data population in each set for the transactions table\n${RESET}")
spark.sql("" +
"SELECT 'hotset', COUNT(*) FROM isk.hotset.transactions WHERE TransactionTime < now() " +
"UNION " +
"SELECT 'coldset', COUNT(*) FROM isk.coldset.transactions WHERE TransactionTime < now() " +
"UNION " +
"SELECT 'merged', COUNT(*) FROM isk.merged.transactions WHERE TransactionTime < now() " +
"").show()

Thread.sleep(sleepTime)

println(s"${GREEN}\n\nMoving data from Kafka to Iceberg is a simple INSERT INTO... SELECT FROM statement with Streambased, we simply select from the hotset into the coldset.\n\nTransferring data in this way has the following advantages:\n\n * Transfer from hotset to coldset is not a pre-requisite for data access\n * It can be scheduled during low resource usage periods.\n * Data can be accumulated in Kafka until it is efficient to transfer it (no small files).\n * The transfer process is atomic and involves no downtime.\n${RESET}")
spark.sql("" +
"INSERT INTO direct.coldset.transactions " +
"SELECT * FROM isk.hotset.transactions " +
"").show()

Thread.sleep(sleepTime)

println(s"${GREEN}\n\nAfter transfer the coldset population has increased. Streambased will now serve a larger share of the merged dataset from the coldset\n\nWhy hasn't the hotset population decreased?\n\nStreambased will not explicitly delete data from Kafka, Kafa deletion is handled by the topic retention policy as usual.\n\nThe merged set now contains all of the coldset + the section of hotset that has not yet been transferred to the coldset as you can see below.\n${RESET}")
spark.sql("" +
"SELECT 'hotset', COUNT(*) FROM isk.hotset.transactions WHERE TransactionTime < now() " +
"UNION " +
"SELECT 'coldset', COUNT(*) FROM isk.coldset.transactions WHERE TransactionTime < now() " +
"UNION " +
"SELECT 'merged', COUNT(*) FROM isk.merged.transactions WHERE TransactionTime < now() " +
"").show()

Thread.sleep(sleepTime)
