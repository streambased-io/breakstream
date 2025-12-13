
println("Before moving from hotset to coldset")
spark.sql("" +
"SELECT 'hotset', COUNT(*) FROM isk.hotset.transactions WHERE TransactionTime < now() " +
"UNION " +
"SELECT 'coldset', COUNT(*) FROM isk.coldset.transactions WHERE TransactionTime < now() " +
"UNION " +
"SELECT 'merged', COUNT(*) FROM isk.merged.transactions WHERE TransactionTime < now() " +
"").show()

println("Before move data")
spark.sql("" +
"INSERT INTO direct.coldset.transactions " +
"SELECT * FROM isk.hotset.transactions " +
"").show()

println("After moving from hotset to coldset")
spark.sql("" +
"SELECT 'hotset', COUNT(*) FROM isk.hotset.transactions WHERE TransactionTime < now() " +
"UNION " +
"SELECT 'coldset', COUNT(*) FROM isk.coldset.transactions WHERE TransactionTime < now() " +
"UNION " +
"SELECT 'merged', COUNT(*) FROM isk.merged.transactions WHERE TransactionTime < now() " +
"").show()

System.exit(0)

