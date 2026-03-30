import scala.io.AnsiColor._
println(s"${GREEN}\n\nRolling hotset to coldset using a single atomic MERGE INTO.\n\nThe source is a UNION of two I.S.K. virtual views:\n\n  * isk.hotset.orders      - live orders (creates + updates, CDC-deduplicated)\n  * isk.cdc_deletes.orders - tombstoned keys (orders deleted from the CDC stream)\n\nThis single MERGE handles all three cases atomically:\n\n  * Key in coldset + hotset (not deleted) -> UPDATE to latest state (e.g. SHIPPED)\n  * Key only in hotset (new order)        -> INSERT into coldset\n  * Key in coldset + cdc_deletes          -> DELETE stale coldset row\n\n${RESET}")
spark.sql("" +
  "MERGE INTO direct.coldset.orders t " +
  "USING ( " +
  "  SELECT OrderID, CustomerID, Status, Amount, kafka_partition, kafka_offset, " +
  "         false as _to_delete " +
  "  FROM isk.hotset.orders " +
  "  UNION ALL " +
  "  SELECT OrderID, " +
  "         CAST(null AS INT)    as CustomerID, " +
  "         CAST(null AS STRING) as Status, " +
  "         CAST(null AS DOUBLE) as Amount, " +
  "         kafka_partition, " +
  "         delete_kafka_offset  as kafka_offset, " +
  "         true                 as _to_delete " +
  "  FROM isk.cdc_deletes.orders " +
  ") s " +
  "ON t.OrderID = s.OrderID " +
  "WHEN MATCHED AND s._to_delete     THEN DELETE " +
  "WHEN MATCHED AND NOT s._to_delete THEN UPDATE SET " +
  "  t.CustomerID = s.CustomerID, t.Status = s.Status, t.Amount = s.Amount, " +
  "  t.kafka_partition = s.kafka_partition, t.kafka_offset = s.kafka_offset " +
  "WHEN NOT MATCHED AND NOT s._to_delete THEN INSERT " +
  "  (OrderID, CustomerID, Status, Amount, kafka_partition, kafka_offset) " +
  "  VALUES (s.OrderID, s.CustomerID, s.Status, s.Amount, s.kafka_partition, s.kafka_offset) " +
  "").show()
println("section complete")
