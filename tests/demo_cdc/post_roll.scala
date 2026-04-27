import scala.io.AnsiColor._
println(s"${GREEN}\n\nAfter the atomic MERGE, the coldset is now fully consistent with the CDC stream:\n\n  * Orders 1-100   - DELETED from coldset (via cdc_deletes branch of the MERGE)\n  * Orders 101-500 - UPDATED in coldset from PENDING -> SHIPPED (hotset wins)\n  * Orders 1001+   - INSERTED into coldset (new orders from background)\n\nThe merged view remains correct throughout with no downtime or inconsistency.\nHotset will shrink naturally as Kafka retention expires the rolled offsets.\n${RESET}")
spark.sql("" +
  "SELECT 'hotset' as source, COUNT(*) as order_count FROM isk.hotset.orders WHERE OrderID > 0 " +
  "UNION ALL " +
  "SELECT 'coldset' as source, COUNT(*) as order_count FROM direct.coldset.orders " +
  "UNION ALL " +
  "SELECT 'merged' as source, COUNT(*) as order_count FROM isk.merged.orders " +
  "").show()
println("section complete")
