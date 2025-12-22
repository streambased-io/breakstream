/*
Verify Kafka vs KSI Functions
*/
import java.util.Properties
import org.apache.kafka.clients.consumer.KafkaConsumer
import collection.JavaConverters._
import collection.mutable._
import java.time.Duration

val rand = new scala.util.Random

println("Look at some records from Kafka")
val consumerProps = new Properties()
consumerProps.put("bootstrap.servers","kafka1:9092")
consumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
consumerProps.put("value.deserializer", "io.confluent.kafka.serializers.KafkaAvroDeserializer")
consumerProps.put("group.id","testGroup" + rand.nextInt())
consumerProps.put("auto.offset.reset", "earliest")
consumerProps.put("schema.registry.url", "http://schema-registry:8081")

val kafkaConsumer =  new KafkaConsumer(consumerProps)
kafkaConsumer.subscribe(ArrayBuffer("transactions").asJava)
var kafkaRecords = kafkaConsumer.poll(Duration.ofSeconds(2))
val startTime = System.currentTimeMillis()
while (kafkaRecords.count() == 0 && (System.currentTimeMillis() - startTime) < 60000) {
  kafkaRecords = kafkaConsumer.poll(Duration.ofSeconds(2))
}
val iter = kafkaRecords.records("transactions").iterator()
var recordsDisplayed = 0
while (iter.hasNext && recordsDisplayed < 10) {
  val record = iter.next()
  println(s"offset = ${record.offset()}, key = ${record.key()}, value = ${record.value()}")
  recordsDisplayed += 1
}

println("Look at some records from Ksi")
val ksiConsumerProps = new Properties()
ksiConsumerProps.put("bootstrap.servers","ksi:9192")
ksiConsumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
ksiConsumerProps.put("value.deserializer", "io.confluent.kafka.serializers.KafkaAvroDeserializer")
ksiConsumerProps.put("group.id","testGroup" + rand.nextInt())
ksiConsumerProps.put("auto.offset.reset", "earliest")
ksiConsumerProps.put("schema.registry.url", "http://schema-registry:8081")

val ksiConsumer =  new KafkaConsumer(ksiConsumerProps)
ksiConsumer.subscribe(ArrayBuffer("transactions").asJava)
var ksiRecords = ksiConsumer.poll(Duration.ofSeconds(2))
val startTime = System.currentTimeMillis()
while (ksiRecords.count() == 0 && (System.currentTimeMillis() - startTime) < 60000) {
  ksiRecords = ksiConsumer.poll(Duration.ofSeconds(2))
}
val ksiIter = ksiRecords.records("transactions").iterator()
var ksiRecordsDisplayed = 0
while (ksiIter.hasNext && ksiRecordsDisplayed < 10) {
  val record = ksiIter.next()
  println(s"offset = ${record.offset()}, key = ${record.key()}, value = ${record.value()}")
  ksiRecordsDisplayed += 1
}



