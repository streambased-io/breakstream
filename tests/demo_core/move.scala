import scala.io.AnsiColor._
println(s"${GREEN}\n\nMoving data from Kafka to Iceberg is a simple INSERT INTO... SELECT FROM statement with Streambased, we simply select from the hotset into the coldset.\n\nTransferring data in this way has the following advantages:\n\n * Transfer from hotset to coldset is not a pre-requisite for data access\n * It can be scheduled during low resource usage periods.\n * Data can be accumulated in Kafka until it is efficient to transfer it (no small files).\n * The transfer process is atomic and involves no downtime.\n${RESET}")
spark.sql("" +
  "INSERT INTO direct.coldset.transactions " +
  "SELECT * FROM isk.hotset.transactions " +
  "").show()
println("section complete")
