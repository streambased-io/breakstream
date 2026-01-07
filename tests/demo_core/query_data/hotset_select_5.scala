println("")
println("The view-based approach takes the query and identifies the relevant Kafka data.")
println("It then returns the data in an Iceberg-friendly format seen below:")
spark.sql("SELECT * FROM isk.hotset.transactions LIMIT 5").show()
