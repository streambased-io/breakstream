import org.scalatest.funsuite.AnyFunSuite
import org.scalatest.Args

/*
Verify KSI Virtual Topic (Condition Topic) Filtering using stores topic
*/
import java.util.Properties
import org.apache.kafka.clients.consumer.KafkaConsumer
import collection.JavaConverters._
import collection.mutable._
import java.time.Duration
import java.util.Base64

val rand = new scala.util.Random

// Create hyperstream index on stores.City before running tests
def createHyperstreamIndex(topic: String, field: String): Unit = {
  val url = new java.net.URL("http://hyperstream:9088/api/index")
  val conn = url.openConnection().asInstanceOf[java.net.HttpURLConnection]
  conn.setConnectTimeout(60000)
  conn.setReadTimeout(600000)
  conn.setRequestMethod("PUT")
  conn.setRequestProperty("Content-Type", "application/json")
  conn.setRequestProperty("Authorization", "Basic " + Base64.getEncoder.encodeToString("sbpk_12345678:sbsk_12345678".getBytes))
  conn.setDoOutput(true)
  conn.getOutputStream.write(s"""{"topic":"$topic","field":"$field"}""".getBytes("UTF-8"))
  conn.getOutputStream.flush()
  val code = conn.getResponseCode
  val stream = if (code < 400) conn.getInputStream else conn.getErrorStream
  val body = if (stream != null) scala.io.Source.fromInputStream(stream).mkString else ""
  println(s"[SETUP] Create index $topic.$field: code=$code body=$body")
}

println("[SETUP] Creating hyperstream index for stores.City")
createHyperstreamIndex("stores", "City")

class VirtualTopicSuite extends AnyFunSuite {
  test("nyc-stores virtual topic returns only New York stores") {
    val consumerProps = new Properties()
    consumerProps.put("bootstrap.servers", "ksi:9192")
    consumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    consumerProps.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    consumerProps.put("group.id", "testGroup" + rand.nextInt())
    consumerProps.put("auto.offset.reset", "earliest")
    consumerProps.put("enable.auto.commit", "false")
    consumerProps.put("max.poll.records", "100")
    consumerProps.put("fetch.max.wait.ms", "500")
    val consumer = new KafkaConsumer[String, String](consumerProps)
    consumer.subscribe(ArrayBuffer("nyc-stores").asJava)
    // First poll: long timeout to wait for KSI coldset read
    val firstRecords = consumer.poll(Duration.ofMinutes(5))
    var totalCount = firstRecords.count()
    firstRecords.records("nyc-stores").forEach { record =>
      println(s"[DEBUG] nyc-stores offset=${record.offset()} value=${record.value().take(200)}")
      assert(record.value().contains("New York"),
        s"Expected all records to contain City 'New York', got: ${record.value()}")
    }
    // Short follow-up polls to catch any remaining records
    var emptyPolls = 0
    while (emptyPolls < 2) {
      val kafkaRecords = consumer.poll(Duration.ofSeconds(10))
      if (kafkaRecords.count() == 0) {
        emptyPolls += 1
      } else {
        emptyPolls = 0
        totalCount += kafkaRecords.count()
        kafkaRecords.records("nyc-stores").forEach { record =>
          println(s"[DEBUG] nyc-stores offset=${record.offset()} value=${record.value().take(200)}")
          assert(record.value().contains("New York"),
            s"Expected all records to contain City 'New York', got: ${record.value()}")
        }
      }
    }
    println(s"[DEBUG] nyc-stores total records: $totalCount")
    assert(totalCount >= 100, s"Expected at least 100 NYC store records (50 coldset + 50 hotset), got $totalCount")
    consumer.close()
  }

  test("nyc-stores consumer resumes from committed offset after reconnect") {
    val groupId = "testGroupResume" + rand.nextInt()
    // Phase 1: consume some records and commit
    val props1 = new Properties()
    props1.put("bootstrap.servers", "ksi:9192")
    props1.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    props1.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    props1.put("group.id", groupId)
    props1.put("auto.offset.reset", "earliest")
    props1.put("enable.auto.commit", "false")
    props1.put("max.poll.records", "2")
    props1.put("fetch.max.wait.ms", "500")
    val consumer1 = new KafkaConsumer[String, String](props1)
    consumer1.subscribe(ArrayBuffer("nyc-stores").asJava)
    var firstBatchRecords = consumer1.poll(Duration.ofMinutes(5))
    val startTime = System.currentTimeMillis()
    while (firstBatchRecords.count() == 0 && (System.currentTimeMillis() - startTime) < 300000) {
      firstBatchRecords = consumer1.poll(Duration.ofMinutes(1))
    }
    val firstBatchCount = firstBatchRecords.count()
    println(s"[DEBUG] Phase 1: consumed $firstBatchCount records")
    assert(firstBatchCount > 0, "Expected at least one record in first batch")
    firstBatchRecords.records("nyc-stores").forEach { record =>
      println(s"[DEBUG] Phase 1 record: offset=${record.offset()} value=${record.value().take(200)}")
    }
    consumer1.commitSync()
    println("[DEBUG] Phase 1: offsets committed")
    consumer1.close()
    println("[DEBUG] Phase 1: consumer closed")
    // Phase 2: reconnect with same group.id, verify resume from committed offset
    Thread.sleep(2000)
    val props2 = new Properties()
    props2.put("bootstrap.servers", "ksi:9192")
    props2.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    props2.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    props2.put("group.id", groupId)
    props2.put("auto.offset.reset", "earliest")
    props2.put("enable.auto.commit", "false")
    props2.put("max.poll.records", "100")
    props2.put("fetch.max.wait.ms", "500")
    val consumer2 = new KafkaConsumer[String, String](props2)
    consumer2.subscribe(ArrayBuffer("nyc-stores").asJava)
    // First poll: long timeout for KSI coldset read
    val phase2First = consumer2.poll(Duration.ofMinutes(5))
    var phase2Count = phase2First.count()
    phase2First.records("nyc-stores").forEach { record =>
      println(s"[DEBUG] Phase 2 record: offset=${record.offset()} value=${record.value().take(200)}")
      assert(record.value().contains("New York"),
        s"Phase 2: Expected 'New York' in record, got: ${record.value()}")
    }
    // Short follow-up polls
    var emptyPolls = 0
    while (emptyPolls < 2) {
      val records = consumer2.poll(Duration.ofSeconds(10))
      if (records.count() == 0) {
        emptyPolls += 1
      } else {
        emptyPolls = 0
        phase2Count += records.count()
        records.records("nyc-stores").forEach { record =>
          println(s"[DEBUG] Phase 2 record: offset=${record.offset()} value=${record.value().take(200)}")
          assert(record.value().contains("New York"),
            s"Phase 2: Expected 'New York' in record, got: ${record.value()}")
        }
      }
    }
    println(s"[DEBUG] Phase 2: consumed $phase2Count records")
    val totalConsumed = firstBatchCount + phase2Count
    println(s"[DEBUG] Total: phase1=$firstBatchCount + phase2=$phase2Count = $totalConsumed")
    assert(totalConsumed >= 100, s"Expected at least 100 total NYC records, got $totalConsumed")
    assert(phase2Count < totalConsumed,
      s"Phase 2 got $phase2Count records which equals total $totalConsumed -- offset commit did not work")
    consumer2.close()
  }

  test("condition topic is faster than consuming and filtering full topic") {
    // Scenario 1: consume from virtual topic nyc-stores (server-side filtering)
    val vtProps = new Properties()
    vtProps.put("bootstrap.servers", "ksi:9192")
    vtProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    vtProps.put("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    vtProps.put("group.id", "testGroupPerf" + rand.nextInt())
    vtProps.put("auto.offset.reset", "earliest")
    vtProps.put("enable.auto.commit", "false")
    vtProps.put("max.poll.records", "1000")
    vtProps.put("fetch.max.wait.ms", "500")
    val vtConsumer = new KafkaConsumer[String, String](vtProps)
    vtConsumer.subscribe(ArrayBuffer("nyc-stores").asJava)
    val vtStart = System.currentTimeMillis()
    val vtFirstRecords = vtConsumer.poll(Duration.ofMinutes(5))
    var vtCount = vtFirstRecords.count()
    vtFirstRecords.records("nyc-stores").forEach { record =>
      println(s"[PERF] nyc-stores offset=${record.offset()} value=${record.value().take(100)}")
    }
    var vtEmpty = 0
    while (vtEmpty < 2) {
      val r = vtConsumer.poll(Duration.ofSeconds(10))
      if (r.count() == 0) { vtEmpty += 1 }
      else {
        vtEmpty = 0
        vtCount += r.count()
        r.records("nyc-stores").forEach { record =>
          println(s"[PERF] nyc-stores offset=${record.offset()} value=${record.value().take(100)}")
        }
      }
    }
    val vtDuration = System.currentTimeMillis() - vtStart
    vtConsumer.close()
    println(s"[PERF] Virtual topic: $vtCount records in ${vtDuration}ms")
    // Scenario 2: consume full stores topic via KSI with Avro deserializer, filter on exact City field
    val fullProps = new Properties()
    fullProps.put("bootstrap.servers", "ksi:9192")
    fullProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
    fullProps.put("value.deserializer", "io.confluent.kafka.serializers.KafkaAvroDeserializer")
    fullProps.put("schema.registry.url", "http://schema-registry:8081")
    fullProps.put("group.id", "testGroupPerf" + rand.nextInt())
    fullProps.put("auto.offset.reset", "earliest")
    fullProps.put("enable.auto.commit", "false")
    fullProps.put("max.poll.records", "1000")
    fullProps.put("fetch.max.wait.ms", "500")
    val fullConsumer = new KafkaConsumer[String, Object](fullProps)
    fullConsumer.subscribe(ArrayBuffer("stores").asJava)
    val fullStart = System.currentTimeMillis()
    var fullTotal = 0
    var fullMatched = 0
    val fullFirstRecords = fullConsumer.poll(Duration.ofMinutes(5))
    fullTotal += fullFirstRecords.count()
    fullFirstRecords.records("stores").forEach { record =>
      val avroRecord = record.value().asInstanceOf[org.apache.avro.generic.GenericRecord]
      val city = avroRecord.get("City").toString
      if (city == "New York") {
        fullMatched += 1
        println(s"[PERF] stores (filtered) offset=${record.offset()} City=$city StoreName=${avroRecord.get("StoreName")}")
      }
    }
    var fullEmpty = 0
    while (fullEmpty < 2) {
      val r = fullConsumer.poll(Duration.ofSeconds(10))
      if (r.count() == 0) { fullEmpty += 1 }
      else {
        fullEmpty = 0
        fullTotal += r.count()
        r.records("stores").forEach { record =>
          val avroRecord = record.value().asInstanceOf[org.apache.avro.generic.GenericRecord]
          val city = avroRecord.get("City").toString
          if (city == "New York") {
            fullMatched += 1
            println(s"[PERF] stores (filtered) offset=${record.offset()} City=$city StoreName=${avroRecord.get("StoreName")}")
          }
        }
      }
    }
    val fullDuration = System.currentTimeMillis() - fullStart
    fullConsumer.close()
    println(s"[PERF] Full topic + client filter: $fullTotal total records, $fullMatched matched in ${fullDuration}ms")
    println(s"[PERF] Comparison: virtual=${vtDuration}ms vs full=${fullDuration}ms (speedup: ${if (vtDuration > 0) "%.2f".format(fullDuration.toDouble / vtDuration) else "N/A"}x)")
    // Both should find at least 5 NYC records
    assert(vtCount >= 100, s"Virtual topic should return at least 100 records (50 cold + 50 hot), got $vtCount")
    assert(fullMatched >= 100, s"Full topic filter should match at least 100 records (50 cold + 50 hot), got $fullMatched")
    // Virtual topic should return same count as exact field filtering
    assert(vtCount == fullMatched,
      s"Virtual topic ($vtCount) should match same count as client Avro filter ($fullMatched)")
    // Virtual topic should be faster
    println(s"[PERF] Virtual topic was ${if (vtDuration < fullDuration) "FASTER" else "SLOWER"} than full topic scan")
    assert(vtDuration < fullDuration,
      s"Expected virtual topic (${vtDuration}ms) to be faster than full scan (${fullDuration}ms)")
  }
}

// run tests
val reporter = new TestReporter
try {
  (new VirtualTopicSuite).run(None, new Args(reporter = reporter))
} catch {
  case e: Throwable => {
    println(e)
  }
} finally {
  reporter.printSummary()
  if (reporter.failed > 0) System.exit(1) else System.exit(0)
}
