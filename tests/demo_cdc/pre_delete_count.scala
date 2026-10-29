import scala.io.AnsiColor._
println(s"${GREEN}\n\nNow let's demonstrate CDC delete handling.\n\nWe are about to inject 100 DELETE events for orders 1-100 into the Kafka CDC stream.\nFirst, let's record the current union order count. Deletes stay in the stream as rows with __op = 'd',\nso the current state excludes them:\n${RESET}")
spark.sql("SELECT COUNT(*) as orders_before_deletes FROM isk.union.orders WHERE OrderID > 0 AND __op <> 'd'").show()
println("section complete")
