import scala.io.AnsiColor._
println(s"${GREEN}\n\nFinally, let's roll the hotset into the coldset.\n\nRight now, the hotset contains new orders and updates to existing orders.\nThe coldset has the original 500 orders from the initial load.\nThe union view has been serving the correct unified view throughout.\n\nCurrent distribution of live orders (excluding __op = 'd'):\n${RESET}")
spark.sql("" +
  "SELECT 'hotset' as source, COUNT(*) as order_count FROM isk.hotset.orders WHERE OrderID > 0 AND __op <> 'd' " +
  "UNION ALL " +
  "SELECT 'coldset' as source, COUNT(*) as order_count FROM direct.coldset.orders WHERE __op <> 'd' " +
  "UNION ALL " +
  "SELECT 'union' as source, COUNT(*) as order_count FROM isk.union.orders WHERE __op <> 'd' " +
  "").show()
println("section complete")
