import scala.io.AnsiColor._
println(s"${GREEN}\n\nLet's look at orders that have been updated to SHIPPED status.\nThese records exist in the coldset as PENDING (from initial load) but the hotset has\nthe latest SHIPPED state. The merged view automatically returns the hotset (newer) value:\n${RESET}")
spark.sql("" +
  "SELECT OrderID, Status as hotset_status FROM isk.hotset.orders WHERE Status = 'SHIPPED' LIMIT 10" +
  "").show()
println(s"${GREEN}\nSame orders in the coldset still show their original PENDING status:${RESET}")
spark.sql("" +
  "SELECT o.OrderID, o.Status as coldset_status " +
  "FROM direct.coldset.orders o " +
  "JOIN isk.hotset.orders h ON o.OrderID = h.OrderID " +
  "WHERE h.Status = 'SHIPPED' " +
  "LIMIT 10" +
  "").show()
println(s"${GREEN}\nBut in the merged view, the hotset (SHIPPED) value wins:${RESET}")
spark.sql("" +
  "SELECT OrderID, Status as merged_status FROM isk.merged.orders WHERE Status = 'SHIPPED' LIMIT 10" +
  "").show()
println("section complete")
