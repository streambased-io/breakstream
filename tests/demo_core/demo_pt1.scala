println("This is Jack's test")
spark.sql("DESCRIBE hotset.transactions").show()

println("Look at my databases")
spark.sql("SHOW DATABASES").show()

println("Look at my hotset tables")
spark.sql("SHOW TABLES IN hotset").show()

println("Look at my coldset tables")
spark.sql("SHOW TABLES IN coldset").show()

println("Look at my merged tables")
spark.sql("SHOW TABLES IN merged").show()

println("How many rows in coldset.transactions?")
spark.sql("SELECT COUNT(*) FROM coldset.transactions").show()

println("How many rows in hotset.transactions?")
spark.sql("SELECT COUNT(*) FROM hotset.transactions").show()

println("How many rows in merged.transactions?")
spark.sql("SELECT COUNT(*) FROM merged.transactions").show()

