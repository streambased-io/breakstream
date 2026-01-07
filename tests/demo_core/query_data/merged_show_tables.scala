println("")
println("You can now see the exclusive tables from both Kafka (\"accounts\") and Iceberg (\"branches\")")
println("joined with the mutual customer and transaction tables.")
spark.sql("SHOW TABLES IN merged").show()
