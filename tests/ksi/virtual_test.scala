import org.scalatest.funsuite.AnyFunSuite
import org.scalatest.Args

/*
Verify KSI Virtual Topic (Condition Topic) Filtering
*/
import java.util.Properties
import org.apache.kafka.clients.consumer.KafkaConsumer
import collection.JavaConverters._
import collection.mutable._
import java.time.Duration

val rand = new scala.util.Random

class VirtualTopicSuite extends AnyFunSuite {
  test("condition topic filters by exact Name match") {
    val consumerProps = new Properties()
    consumerProps.put("bootstrap.servers", "ksi:9192")
    consumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    consumerProps.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    consumerProps.put("group.id", "testGroup" + rand.nextInt())
    consumerProps.put("auto.offset.reset", "earliest")
    consumerProps.put("enable.auto.commit", "false")
    consumerProps.put("max.poll.records", "10")
    consumerProps.put("fetch.max.wait.ms", "500")
    val consumer = new KafkaConsumer[String, String](consumerProps)
    consumer.subscribe(ArrayBuffer("test-customers").asJava)
    val kafkaRecords = consumer.poll(Duration.ofMinutes(10))
    println(s"[DEBUG] test-customers poll returned ${kafkaRecords.count()} records")
    assert(kafkaRecords.count() > 0, "Expected records from virtual topic test-customers")
    val records = kafkaRecords.records("test-customers")
    records.forEach { record =>
      println(s"[DEBUG] record offset=${record.offset()} value=${record.value().take(200)}")
      assert(record.value().contains("Judith Gottlieb Streambased2"),
        s"Expected all records to contain Name 'Judith Gottlieb Streambased1', got: ${record.value()}")
    }
    consumer.close()
  }

  test("condition topic filters by UPPER Name") {
    val consumerProps = new Properties()
    consumerProps.put("bootstrap.servers", "ksi:9192")
    consumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    consumerProps.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    consumerProps.put("group.id", "testGroup" + rand.nextInt())
    consumerProps.put("auto.offset.reset", "earliest")
    consumerProps.put("enable.auto.commit", "false")
    consumerProps.put("max.poll.records", "10")
    consumerProps.put("fetch.max.wait.ms", "500")
    val consumer = new KafkaConsumer[String, String](consumerProps)
    consumer.subscribe(ArrayBuffer("streambased-customers").asJava)
    val kafkaRecords = consumer.poll(Duration.ofMinutes(10))
    println(s"[DEBUG] streambased-customers poll returned ${kafkaRecords.count()} records")
    assert(kafkaRecords.count() > 0, "Expected records from virtual topic streambased-customers")
    val records = kafkaRecords.records("streambased-customers")
    records.forEach { record =>
      println(s"[DEBUG] record offset=${record.offset()} value=${record.value().take(200)}")
      assert(record.value().contains("Judith Gottlieb Streambased2"),
        s"Expected all records to contain 'Judith Gottlieb Streambased1', got: ${record.value()}")
    }
    consumer.close()
  }

  test("condition topic returns fewer records than source topic") {
    val filteredProps = new Properties()
    filteredProps.put("bootstrap.servers", "ksi:9192")
    filteredProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    filteredProps.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    filteredProps.put("group.id", "testGroup" + rand.nextInt())
    filteredProps.put("auto.offset.reset", "earliest")
    filteredProps.put("enable.auto.commit", "false")
    filteredProps.put("max.poll.records", "10")
    filteredProps.put("fetch.max.wait.ms", "500000")
    val filteredConsumer = new KafkaConsumer[String, String](filteredProps)
    filteredConsumer.subscribe(ArrayBuffer("test-customers").asJava)
    val filteredRecords = filteredConsumer.poll(Duration.ofMinutes(10))
    val filteredCount = filteredRecords.count()
    println(s"[DEBUG] filtered poll returned $filteredCount records")
    filteredConsumer.close()
    val fullProps = new Properties()
    fullProps.put("bootstrap.servers", "ksi:9192")
    fullProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    fullProps.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    fullProps.put("group.id", "testGroup" + rand.nextInt())
    fullProps.put("auto.offset.reset", "earliest")
    fullProps.put("enable.auto.commit", "false")
    fullProps.put("max.poll.records", "10")
    fullProps.put("fetch.max.wait.ms", "500000")
    val fullConsumer = new KafkaConsumer[String, String](fullProps)
    fullConsumer.subscribe(ArrayBuffer("customers").asJava)
    val fullRecords = fullConsumer.poll(Duration.ofMinutes(10))
    val fullCount = fullRecords.count()
    println(s"[DEBUG] full customers poll returned $fullCount records")
    fullConsumer.close()
    assert(filteredCount > 0, "Expected at least one filtered record")
    assert(filteredCount < fullCount,
      s"Expected filtered count ($filteredCount) to be less than full count ($fullCount)")
  }
}

// run tests
try {
  (new VirtualTopicSuite).run(None, new Args(reporter = new TestReporter))
} catch {
  case e: Throwable => {
    println(e)
    System.exit(1)
  }
} finally {
  System.exit(0)
}
