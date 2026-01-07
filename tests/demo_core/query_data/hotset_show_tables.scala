println("")
println("Within the hotset we can see how Kafka topics are surfaced as Iceberg tables:")
spark.sql("SHOW TABLES IN hotset").show()
println("""Note: the "accounts" topic exists exclusively in Kafka. There is no corresponding folder in MinIO.""")
