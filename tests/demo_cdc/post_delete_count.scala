import scala.io.AnsiColor._
println(s"${GREEN}\n\n100 DELETE events for orders 1-100 have been published to the Kafka CDC stream.\n\nI.S.K. keeps each delete as a row with __op = 'd' that replaces the original record in the hotset and union views.\nLet's verify the current-state count in the union view (excluding __op = 'd') has dropped accordingly:\n${RESET}")
spark.sql("" +
  "SELECT COUNT(*) as orders_after_deletes FROM isk.union.orders WHERE OrderID > 0 AND __op <> 'd'" +
  "").show()
println(s"${GREEN}The delete rows themselves are still in the view, so downstream consumers can see what was deleted:${RESET}")
spark.sql("" +
  "SELECT COUNT(*) as delete_rows FROM isk.union.orders WHERE OrderID > 0 AND __op = 'd'" +
  "").show()
println(s"${GREEN}The original PENDING records still physically exist in the coldset, but the union view hides them behind the newer delete rows.${RESET}")
println("section complete")
