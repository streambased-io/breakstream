import scala.io.AnsiColor._
println(s"${GREEN}\n\nNow let's demonstrate CDC delete handling.\n\nWe are about to inject 100 DELETE events for orders 1-100 into the Kafka CDC stream.\nFirst, let's record the current merged order count:\n${RESET}")
spark.sql("SELECT COUNT(*) as orders_before_deletes FROM isk.merged.orders").show()
println("section complete")
