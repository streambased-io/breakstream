import scala.io.AnsiColor._
println(s"${GREEN}\n\nLet's look at orders that have been updated to SHIPPED status.\nThese records exist in the coldset as PENDING (from initial load) but the hotset has\nthe latest SHIPPED state. The union view automatically returns the hotset (newer) value:\n${RESET}")
spark.sql("" +
  "SELECT OrderID, Status as hotset_status FROM isk.hotset.orders WHERE Status = 'SHIPPED' ORDER BY OrderID ASC LIMIT 10" +
  "").show()
println(s"${GREEN}\nSame orders in the coldset still show their original PENDING status:${RESET}")
spark.sql("" +
  "SELECT o.OrderID, o.Status as coldset_status " +
  "FROM direct.coldset.orders o " +
  "JOIN isk.hotset.orders h ON o.OrderID = h.OrderID " +
  "WHERE h.Status = 'SHIPPED' " +
  "ORDER BY o.OrderID ASC LIMIT 10" +
  "").show()
println(s"${GREEN}\nBut in the union view, the hotset (SHIPPED) value wins:${RESET}")
spark.sql("" +
  "SELECT OrderID, Status as union_status FROM isk.union.orders WHERE Status = 'SHIPPED' ORDER BY OrderID ASC LIMIT 10" +
  "").show()
println("section complete")
