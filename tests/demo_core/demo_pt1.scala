import scala.io.AnsiColor._

val sleepTime = 15000

println(s"${GREEN}\n\nWe begin by describing the databases available. We see:\n\n * hotset - data from Kafka only\n * coldset - data from Iceberg only\n * merged - a hotset and coldset seamlessly unioned by Streambased.\n\nOnly the coldset database physically exists, hotset and merged are virtual databases provided by Streambased I.S.K.\n${RESET}")
spark.sql("SHOW DATABASES").show()

Thread.sleep(sleepTime)

println(s"${GREEN}\n\nLet's list hostet tables. These correspond exactly to topics in Kafka.\n\nIf new topics are added they will immediately appear here.\n\nThe accounts table exists in Kafka only and has no Iceberg equivalent.\n${RESET}")
spark.sql("SHOW TABLES IN hotset").show()

Thread.sleep(sleepTime)

println(s"${GREEN}\n\nNow let's list coldset tables. These correspond exactly to tables in Iceberg.\n\nAgain, if new tables are added they will immediately appear here.\n\nThe branches table exists in Iceberg only and has no Kafka equivalent.\n${RESET}")
spark.sql("SHOW TABLES IN coldset").show()

Thread.sleep(sleepTime)

println(s"${GREEN}\n\nFinally, let's list merged tables. This is the union of topics in Kafka and tables in Iceberg.\n\nAny that exist in both Kafka and Iceberg (e.g. transactions) are intelligently unioned by Streambased.\n${RESET}")
spark.sql("SHOW TABLES IN merged").show()

Thread.sleep(sleepTime)

println(s"${GREEN}\n\nTo show the union, let's confirm the data size of the transactions topic on each view.\n\nFirst the coldset, here we see the transactions data stored in Iceberg\n${RESET}")
spark.sql("SELECT COUNT(*) FROM coldset.transactions").show()

Thread.sleep(sleepTime)

println(s"${GREEN}\n\nNow the data size of the transactions topic in the hotset.\n\nHere we see the transactions data stored in Kafka\n${RESET}")
spark.sql("SELECT COUNT(*) FROM hotset.transactions").show()

Thread.sleep(sleepTime)

println(s"${GREEN}\n\nAnd now the data size of the transactions topic in the merged set.\n\nThis is a seamless combination of Kafka and Iceberg data.\n\nWhy doesn't the merged size equal hotset + coldset?\n\nStreambased garuntees that any queries will run against the latest data available at the time of query execution. As the hotset is being constantly written to, more data is available in it now than there was when we queried the hotset individually\n${RESET}")
spark.sql("SELECT COUNT(*) FROM merged.transactions").show()

Thread.sleep(sleepTime)
