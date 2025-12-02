import org.scalatest.FunSuite
import org.scalatest.Args

/*
Verify Kafka vs KSI Functions
*/
var exitCode = 0

import java.util.Properties
import org.apache.kafka.clients.consumer.KafkaConsumer
import collection.JavaConverters._
import collection.mutable._
import java.time.Duration

val rand = new scala.util.Random

class CoreFunctionsSuite extends FunSuite {
  test("kafka starts from hotset") {
    val consumerProps = new Properties()
    consumerProps.put("bootstrap.servers","kafka1:9092")
    consumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    consumerProps.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    consumerProps.put("group.id","testGroup" + rand.nextInt())
    consumerProps.put("auto.offset.reset", "earliest")


    val kafkaConsumer =  new KafkaConsumer(consumerProps)
    kafkaConsumer.subscribe(ArrayBuffer("transactions").asJava)
    var kafkaRecords = kafkaConsumer.poll(Duration.ofSeconds(2))
    while (kafkaRecords.count() == 0) {
      kafkaRecords = kafkaConsumer.poll(Duration.ofSeconds(2))
    }
    assert(kafkaRecords.records("transactions").iterator().next().offset == 500000)
  }

  test("ksi starts from coldset") {
    val consumerProps = new Properties()
    consumerProps.put("bootstrap.servers","ksi:9192")
    consumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    consumerProps.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    consumerProps.put("group.id","testGroup" + rand.nextInt())
    consumerProps.put("auto.offset.reset", "earliest")


    val kafkaConsumer =  new KafkaConsumer(consumerProps)
    kafkaConsumer.subscribe(ArrayBuffer("transactions").asJava)
    var kafkaRecords = kafkaConsumer.poll(Duration.ofSeconds(2))
    while (kafkaRecords.count() == 0) {
      kafkaRecords = kafkaConsumer.poll(Duration.ofSeconds(2))
    }
    assert(kafkaRecords.records("transactions").iterator().next().offset == 0)
  }
}

// run tests
try {
  (new CoreFunctionsSuite).run(None, new Args(reporter = new TestReporter))
} catch {
  case e: Throwable => {
    println(e)
    System.exit(1)
  }
} finally {
  val isComplete = true
  System.exit(exitCode)
}