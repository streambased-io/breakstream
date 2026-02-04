import java.util.Properties
import org.apache.kafka.clients.consumer.KafkaConsumer
import collection.JavaConverters._
import collection.mutable._
import java.time.Duration
import scala.io.AnsiColor._

val rand = new scala.util.Random

println(s"${GREEN}\n\nStreambased allows you to use the coldset data stored in Iceberg to serve Kafka applications.\n\nIn the setup process for this demo we wrote a chunk of data to Kafka, transferred it to Iceberg and the deleted it from Kafka. A Kafka consumer should no longer be able to read this data.\n\nLet's run a sample application that reads directly from Kafka to prove this.\n\nThe application below will connect to Kafka and read from the earliest data available. A non-zero offset means that some original data is missing.\n${RESET}")

val consumerProps = new Properties()
consumerProps.put("bootstrap.servers","kafka1:9092")
consumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
consumerProps.put("value.deserializer", "io.confluent.kafka.serializers.KafkaAvroDeserializer")
consumerProps.put("group.id","testGroup" + rand.nextInt())
consumerProps.put("auto.offset.reset", "earliest")
consumerProps.put("schema.registry.url", "http://schema-registry:8081")
val kafkaConsumer =  new KafkaConsumer(consumerProps)

println("section complete")
