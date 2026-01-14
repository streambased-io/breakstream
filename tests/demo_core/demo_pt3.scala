import java.util.Properties
import org.apache.kafka.clients.consumer.KafkaConsumer
import collection.JavaConverters._
import collection.mutable._
import java.time.Duration
import scala.io.AnsiColor._

val rand = new scala.util.Random

val sleepTime = 15000

println(s"${GREEN}\n\nStreambased allows you to use the coldset data stored in Iceberg to serve Kafka applications.\n\nIn the setup process for this demo we wrote a chunk of data to Kafka, transferred it to Iceberg and the deleted it from Kafka. A Kafka consumer should no longer be able to read this data.\n\nLet's run a sample application that reads directly from Kafka to prove this.\n\nThe application below will connect to Kafka and read from the earliest data available. A non-zero offset means that some original data is missing.\n${RESET}")

Thread.sleep(sleepTime)

val consumerProps = new Properties()
consumerProps.put("bootstrap.servers","kafka1:9092")
consumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
consumerProps.put("value.deserializer", "io.confluent.kafka.serializers.KafkaAvroDeserializer")
consumerProps.put("group.id","testGroup" + rand.nextInt())
consumerProps.put("auto.offset.reset", "earliest")
consumerProps.put("schema.registry.url", "http://schema-registry:8081")
val kafkaConsumer =  new KafkaConsumer(consumerProps)

println("")
println("")
println(s"${GREEN}\n\nLet's fetch some messages!${RESET}")
println("")
println("")

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
  println(s"offset = ${RED}${record.offset()}${RESET}, key = ${record.key()}, value = ${record.value()}")
  recordsDisplayed += 1
}

Thread.sleep(sleepTime)

println(s"${GREEN}\n\nNow let's read using the Streambased proxy  Notice that the Kafka client configurations stay the same, it is merely pointed at a different bootstrap server.\n\nStreambased serves the data we transferred to Iceberg previously as if it was Kafka data allowing us to restore access to the previously deleted records.\n\nYou canb confirm this by noting that the first offset retrieved is now 0\n${RESET}")

Thread.sleep(sleepTime)

val ksiConsumerProps = new Properties()
ksiConsumerProps.put("bootstrap.servers","ksi:9192")
ksiConsumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
ksiConsumerProps.put("value.deserializer", "io.confluent.kafka.serializers.KafkaAvroDeserializer")
ksiConsumerProps.put("group.id","testGroup" + rand.nextInt())
ksiConsumerProps.put("auto.offset.reset", "earliest")
ksiConsumerProps.put("schema.registry.url", "http://schema-registry:8081")
val ksiConsumer =  new KafkaConsumer(ksiConsumerProps)


println("")
println("")
println(s"${GREEN}\n\nLet's fetch some messages!${RESET}")
println("")
println("")

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
  println(s"offset = ${RED}${record.offset()}${RESET}, key = ${record.key()}, value = ${record.value()}")
  ksiRecordsDisplayed += 1
}

Thread.sleep(sleepTime)
