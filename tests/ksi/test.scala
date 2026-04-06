import org.scalatest.funsuite.AnyFunSuite
import org.scalatest.Args

/*
Verify Kafka vs KSI Functions and Condition Topic Filtering
*/
import java.util.Properties
import org.apache.kafka.clients.consumer.KafkaConsumer
import collection.JavaConverters._
import collection.mutable._
import java.time.Duration

val rand = new scala.util.Random

class KsiSuite extends AnyFunSuite {
  test("kafka starts from hotset") {
    val consumerProps = new Properties()
    consumerProps.put("bootstrap.servers","kafka1:9092")
    consumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    consumerProps.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    consumerProps.put("group.id","testGroup" + rand.nextInt())
    consumerProps.put("auto.offset.reset", "earliest")
    val kafkaConsumer = new KafkaConsumer(consumerProps)
    kafkaConsumer.subscribe(ArrayBuffer("transactions").asJava)
    var kafkaRecords = kafkaConsumer.poll(Duration.ofSeconds(2))
    val startTime = System.currentTimeMillis()
    while (kafkaRecords.count() == 0 && (System.currentTimeMillis() - startTime) < 60000) {
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
    val kafkaConsumer = new KafkaConsumer(consumerProps)
    kafkaConsumer.subscribe(ArrayBuffer("transactions").asJava)
    var kafkaRecords = kafkaConsumer.poll(Duration.ofSeconds(2))
    val startTime = System.currentTimeMillis()
    while (kafkaRecords.count() == 0 && (System.currentTimeMillis() - startTime) < 60000) {
      kafkaRecords = kafkaConsumer.poll(Duration.ofSeconds(2))
    }
    assert(kafkaRecords.records("transactions").iterator().next().offset == 0)
  }

//  test("ksi reads coldset transactions with timestamp-micros field") {
//    // Regression: SparkRowSerializer fails with ClassCastException
//    // Long cannot be cast to LocalDateTime when reading timestamp-micros columns
//    // from Iceberg via Spark Connect (TransactionTime field)
//    val consumerProps = new Properties()
//    consumerProps.put("bootstrap.servers", "ksi:9192")
//    consumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
//    consumerProps.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
//    consumerProps.put("group.id", "testGroup" + rand.nextInt())
//    consumerProps.put("auto.offset.reset", "earliest")
//    val consumer = new KafkaConsumer[String, String](consumerProps)
//    consumer.subscribe(ArrayBuffer("transactions").asJava)
//    var kafkaRecords = consumer.poll(Duration.ofSeconds(2))
//    val startTime = System.currentTimeMillis()
//    while (kafkaRecords.count() == 0 && (System.currentTimeMillis() - startTime) < 60000) {
//      kafkaRecords = consumer.poll(Duration.ofSeconds(2))
//    }
//    assert(kafkaRecords.count() > 0, "Expected coldset transaction records from KSI")
//    val firstRecord = kafkaRecords.records("transactions").iterator().next()
//    assert(firstRecord.offset() == 0, s"Expected coldset offset 0, got ${firstRecord.offset()}")
//    assert(firstRecord.value().contains("TransactionTime"),
//      s"Expected record to contain TransactionTime field, got: ${firstRecord.value()}")
//    // Consume multiple batches to ensure timestamp serialization works across records
//    var totalRecords = kafkaRecords.count()
//    val batchStart = System.currentTimeMillis()
//    while (totalRecords < 1000 && (System.currentTimeMillis() - batchStart) < 30000) {
//      kafkaRecords = consumer.poll(Duration.ofSeconds(2))
//      totalRecords += kafkaRecords.count()
//    }
//    assert(totalRecords >= 1000,
//      s"Expected at least 1000 coldset records with timestamps, got $totalRecords")
//    consumer.close()
//  }

}

// run tests
try {
  (new KsiSuite).run(None, new Args(reporter = new TestReporter))
} catch {
  case e: Throwable => {
    println(e)
    System.exit(1)
  }
} finally {
  System.exit(0)
}
