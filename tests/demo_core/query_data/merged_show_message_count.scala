println("")
println("Looking at the message count is another excellent way of visualising the combined data.")
println("Below we see the coldset total, the merged total and the hotset total:")

spark.sql("""
  SELECT 'coldset', COUNT(*) FROM isk.coldset.transactions WHERE TransactionTime < now()
""").show()

spark.sql("""
  SELECT 'merged', COUNT(*) FROM isk.merged.transactions WHERE TransactionTime < now()
""").show()

spark.sql("""
  SELECT 'hotset', COUNT(*) FROM isk.hotset.transactions WHERE TransactionTime < now()
""").show()

println("Note how the merged count is roughly the combination of the coldset count and the hotset count.")
println("The hotset count is slightly higher because new messages will have arrived between the second and third queries.")
