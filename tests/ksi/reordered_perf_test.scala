import org.scalatest.funsuite.AnyFunSuite
import org.scalatest.Args

/*
Measure KSI reordered-group consume performance against reordered_perf_customers.
The dataset contains 2,000,000 matching coldset records. Tune target depth with:
  REORDERED_PERF_TARGET_RECORDS, REORDERED_PERF_MAX_POLL_RECORDS, REORDERED_PERF_EMPTY_POLLS
*/
import java.time.Duration
import java.util.Collections
import java.util.Properties
import org.apache.avro.generic.GenericRecord
import org.apache.kafka.clients.admin.AdminClient
import org.apache.kafka.clients.consumer.ConsumerRecord
import org.apache.kafka.clients.consumer.KafkaConsumer
import collection.JavaConverters._

val perfTopic = "reordered_perf_customers"
val perfGroup = "reordered-e2e-performance"
val perfClient = "consumer-reordered-e2e-performance"
val perfMatchName = "Reordered Perf Match"
val targetRecords = sys.env.get("REORDERED_PERF_TARGET_RECORDS").map(_.toInt).getOrElse(1000000)
val maxPollRecords = sys.env.get("REORDERED_PERF_MAX_POLL_RECORDS").map(_.toInt).getOrElse(1000)
val emptyPollLimit = sys.env.get("REORDERED_PERF_EMPTY_POLLS").map(_.toInt).getOrElse(3)

def createAdminClient(): AdminClient = {
  val adminProps = new Properties()
  adminProps.put("bootstrap.servers", "kafka1:9092")
  AdminClient.create(adminProps)
}

def deleteConsumerGroup(groupId: String): Unit = {
  val admin = createAdminClient()
  try {
    admin.deleteConsumerGroups(Collections.singletonList(groupId)).all().get()
  } catch {
    case _: Throwable =>
  } finally {
    admin.close()
  }
}

def createConsumer(): KafkaConsumer[String, Object] = {
  val consumerProps = new Properties()
  consumerProps.put("bootstrap.servers", "ksi:9192")
  consumerProps.put("group.id", perfGroup)
  consumerProps.put("client.id", perfClient)
  consumerProps.put("auto.offset.reset", "earliest")
  consumerProps.put("enable.auto.commit", "false")
  consumerProps.put("max.poll.records", maxPollRecords.toString)
  consumerProps.put("fetch.max.wait.ms", "500")
  consumerProps.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer")
  consumerProps.put("value.deserializer", "io.confluent.kafka.serializers.KafkaAvroDeserializer")
  consumerProps.put("schema.registry.url", "http://schema-registry:8081")
  consumerProps.put("specific.avro.reader", "false")
  new KafkaConsumer[String, Object](consumerProps)
}

def recordName(record: ConsumerRecord[String, Object]): String = {
  record.value().asInstanceOf[GenericRecord].get("Name").toString
}

class ReorderedPerfSuite extends AnyFunSuite {
  test("consume reordered performance topic and report batch latency") {
    deleteConsumerGroup(perfGroup)

    val consumer = createConsumer()
    consumer.subscribe(Collections.singletonList(perfTopic))

    var totalRecords = 0L
    var batchNumber = 0
    var emptyPolls = 0
    var firstOffset = -1L
    var lastOffset = -1L
    val batchLatencies = scala.collection.mutable.ArrayBuffer.empty[Long]
    val startedAt = System.currentTimeMillis()

    while (totalRecords < targetRecords && emptyPolls < emptyPollLimit) {
      val pollStartedAt = System.currentTimeMillis()
      val records = consumer.poll(Duration.ofSeconds(30))
      val elapsedMs = System.currentTimeMillis() - pollStartedAt
      val topicRecords = records.records(perfTopic).asScala.toList

      if (topicRecords.isEmpty) {
        emptyPolls += 1
        println(s"[PERF] empty poll $emptyPolls/$emptyPollLimit after ${elapsedMs}ms")
      } else {
        emptyPolls = 0
        batchNumber += 1
        batchLatencies += elapsedMs
        if (firstOffset < 0) {
          firstOffset = topicRecords.head.offset()
        }
        lastOffset = topicRecords.last.offset()

        val badRecord = topicRecords.find(recordName(_) != perfMatchName)
        assert(badRecord.isEmpty, s"Expected all records to match Name='$perfMatchName'")

        val expectedFirstOffset = totalRecords
        assert(topicRecords.head.offset() == expectedFirstOffset,
          s"Expected first offset in batch $batchNumber to be $expectedFirstOffset, got ${topicRecords.head.offset()}")

        totalRecords += topicRecords.size
        consumer.commitSync()

        println(
          s"[PERF] batch=$batchNumber records=${topicRecords.size} elapsedMs=$elapsedMs " +
          s"offsetRange=${topicRecords.head.offset()}-${topicRecords.last.offset()} total=$totalRecords"
        )
      }
    }

    consumer.close()

    val totalElapsedMs = System.currentTimeMillis() - startedAt
    assert(totalRecords > 0, "Expected performance consumer to receive reordered records")
    assert(firstOffset == 0, s"Expected synthetic offsets to start at 0, got $firstOffset")
    assert(totalRecords >= targetRecords || emptyPolls == 0,
      s"Stopped before targetRecords=$targetRecords after emptyPolls=$emptyPolls, totalRecords=$totalRecords")

    val sortedLatencies = batchLatencies.sorted
    val avgLatency = if (batchLatencies.nonEmpty) batchLatencies.sum.toDouble / batchLatencies.size else 0.0
    val p50 = if (sortedLatencies.nonEmpty) sortedLatencies(sortedLatencies.size / 2) else 0L
    val p95 = if (sortedLatencies.nonEmpty) sortedLatencies(math.min(sortedLatencies.size - 1, math.ceil(sortedLatencies.size * 0.95).toInt - 1)) else 0L
    val throughput = if (totalElapsedMs > 0) totalRecords.toDouble / (totalElapsedMs.toDouble / 1000.0) else 0.0

    println("")
    println("=" * 80)
    println(s"REORDERED PERF SUMMARY")
    println(s"topic=$perfTopic group=$perfGroup")
    println(s"targetRecords=$targetRecords consumedRecords=$totalRecords batches=$batchNumber")
    println(s"firstOffset=$firstOffset lastOffset=$lastOffset")
    println(f"totalElapsedMs=$totalElapsedMs throughputRecordsPerSec=$throughput%.2f")
    println(f"batchLatencyMs avg=$avgLatency%.2f p50=$p50 p95=$p95")
    println("=" * 80)
    println("")
  }
}

val reporter = new TestReporter
try {
  (new ReorderedPerfSuite).run(None, new Args(reporter = reporter))
} catch {
  case e: Throwable => {
    e.printStackTrace()
    println(e)
  }
} finally {
  reporter.printSummary()
  if (reporter.failed > 0) System.exit(1) else System.exit(0)
}
