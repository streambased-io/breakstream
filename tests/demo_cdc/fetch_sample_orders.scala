import scala.io.AnsiColor._
println(s"${GREEN}\n\nHere are 10 sample orders from the hotset.\nNotice that orders with status SHIPPED have been updated in-place by the CDC stream.\nEach order ID appears only once, showing the most recent state:\n${RESET}")
spark.sql("SELECT OrderID, CustomerID, Status, Amount FROM isk.hotset.orders ORDER BY OrderID LIMIT 10").show()
println("section complete")
