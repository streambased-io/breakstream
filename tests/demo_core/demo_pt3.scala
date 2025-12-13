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
consumerProps.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
consumerProps.put("group.id","testGroup" + rand.nextInt())
consumerProps.put("auto.offset.reset", "earliest")

val kafkaConsumer =  new KafkaConsumer(consumerProps)
kafkaConsumer.subscribe(ArrayBuffer("transactions").asJava)
var kafkaRecords = kafkaConsumer.poll(Duration.ofSeconds(2))
val startTime = System.currentTimeMillis()
while (kafkaRecords.count() == 0 && (System.currentTimeMillis() - startTime) < 60000) {
  kafkaRecords = kafkaConsumer.poll(Duration.ofSeconds(2))
}
val iter = kafkaRecords.records("transactions").iterator()
while (iter.hasNext) {
  val record = iter.next()
  println(s"offset = ${record.offset()}, key = ${record.key()}, value = ${record.value()}")
}
