import scala.io.AnsiColor._
println(s"${GREEN}\n\nMoving data from Kafka to Iceberg is a simple INSERT INTO... SELECT FROM statement with Streambased, we simply select from the hotset into the coldset.\n\nTransferring data in this way has the following advantages:\n\n * Transfer from hotset to coldset is not a pre-requisite for data access\n * It can be scheduled during low resource usage periods.\n * Data can be accumulated in Kafka until it is efficient to transfer it (no small files).\n * The transfer process is atomic and involves no downtime.\n\nBut first we need to add the new column to the coldset - reflecting the Kafka schema evolution\n${RESET}")
spark.sql("" +
  "ALTER TABLE direct.coldset.transactions " +
  " ADD COLUMN FraudRiskScore double AFTER TransactionTime" +
  "").show()
println(s"${GREEN}\n\nLets verify the schema by doing describe table: ${RESET}")
spark.sql("" +
  "DESCRIBE direct.coldset.transactions " +
  "").show()
println("section complete")
