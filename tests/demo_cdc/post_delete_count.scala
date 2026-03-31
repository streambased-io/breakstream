import scala.io.AnsiColor._
println(s"${GREEN}\n\n100 DELETE events for orders 1-100 have been published to the Kafka CDC stream.\n\nI.S.K. processes these tombstones and suppresses the deleted records from all views.\nLet's verify the merged count has dropped accordingly:\n${RESET}")
spark.sql("" +
  "SELECT COUNT(*) as orders_after_deletes FROM isk.merged.orders WHERE OrderID > 0" +
  "").show()
println(s"${GREEN}Deleted orders are gone from the merged view. They are also suppressed from the coldset\nwhere the original PENDING records still physically exist - but are hidden by the CDC delete index.${RESET}")
println("section complete")
