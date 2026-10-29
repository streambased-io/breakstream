import scala.io.AnsiColor._
println(s"${GREEN}\n\nAfter the roll, the coldset is now fully consistent with the CDC stream:\n\n  * Orders 1-100   - kept in coldset as delete rows (__op = 'd'), excluded from the current state\n  * Orders 101-500 - UPDATED in coldset from PENDING -> SHIPPED (hotset wins)\n  * Orders 1001+   - INSERTED into coldset (new orders from background)\n\nThe union view remains correct throughout with no downtime or inconsistency.\nStraight after the roll the hotset holds only the unrolled CDC window.\n${RESET}")
spark.sql("" +
  "SELECT 'hotset' as source, COUNT(*) as order_count FROM isk.hotset.orders WHERE OrderID > 0 AND __op <> 'd' " +
  "UNION ALL " +
  "SELECT 'coldset' as source, COUNT(*) as order_count FROM direct.coldset.orders WHERE __op <> 'd' " +
  "UNION ALL " +
  "SELECT 'union' as source, COUNT(*) as order_count FROM isk.union.orders WHERE __op <> 'd' " +
  "").show()
println("section complete")
