import scala.io.AnsiColor._
println(s"${GREEN}\n\nLet's check the order counts across all three views.\n\nThe coldset holds the 500 orders from the initial load.\nThe hotset is growing as new orders arrive and existing ones are updated.\nThe union view combines both, with the hotset taking precedence for keys that appear in both.\n${RESET}")
spark.sql("" +
  "SELECT 'hotset' as source, COUNT(*) as order_count FROM isk.hotset.orders WHERE OrderID > 0 " +
  "UNION ALL " +
  "SELECT 'coldset' as source, COUNT(*) as order_count FROM direct.coldset.orders " +
  "UNION ALL " +
  "SELECT 'union' as source, COUNT(*) as order_count FROM isk.union.orders " +
  "").show()
println("section complete")
