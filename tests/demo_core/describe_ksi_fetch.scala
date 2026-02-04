println(s"${GREEN}\n\nNow let's read using the Streambased proxy  Notice that the Kafka client configurations stay the same, it is merely pointed at a different bootstrap server.\n\nStreambased serves the data we transferred to Iceberg previously as if it was Kafka data allowing us to restore access to the previously deleted records.\n\nYou can confirm this by noting that the first offset retrieved is now 0\n${RESET}")

val ksiConsumerProps = new Properties()
ksiConsumerProps.put("bootstrap.servers","ksi:9192")
ksiConsumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
ksiConsumerProps.put("value.deserializer", "io.confluent.kafka.serializers.KafkaAvroDeserializer")
ksiConsumerProps.put("group.id","testGroup" + rand.nextInt())
ksiConsumerProps.put("auto.offset.reset", "earliest")
ksiConsumerProps.put("schema.registry.url", "http://schema-registry:8081")
val ksiConsumer =  new KafkaConsumer(ksiConsumerProps)

println("section complete")
