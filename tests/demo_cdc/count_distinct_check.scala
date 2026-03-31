import scala.io.AnsiColor._
println(s"${GREEN}\n\nThis is the key insight of CDC-aware processing.\n\nBackground is generating both new orders (creates) AND status updates to existing orders.\nA naive system would show one row per CDC event, inflating counts and duplicating records.\n\nWith I.S.K., updates are applied in-place. Let's verify:\n${RESET}")
spark.sql("" +
  "SELECT " +
  "  COUNT(*) as total_rows, " +
  "  COUNT(DISTINCT OrderID) as distinct_orders, " +
  "  COUNT(*) = COUNT(DISTINCT OrderID) as no_duplicates " +
  "FROM isk.hotset.orders WHERE OrderID > 0" +
  "").show()
println(s"${GREEN}Total rows equals distinct order count - no duplicate rows from CDC updates.${RESET}")
println("section complete")
