import org.scalatest.funsuite.AnyFunSuite
import org.scalatest.Args

/*
Measure KSI reordered-group consume performance against baseline and ordered coldset topics,
then compare against a normal Kafka topic with the same record shape.
Each topic contains 2,000,000 records. Tune target depth with:
  REORDERED_PERF_TARGET_RECORDS, REORDERED_PERF_KSI_MAX_POLL_RECORDS,
  REORDERED_PERF_KAFKA_MAX_POLL_RECORDS, REORDERED_PERF_EMPTY_POLLS,
  REORDERED_PERF_CASES
*/
import java.time.Duration
import java.time.Instant
import java.util.Collections
import java.util.Properties
import org.apache.kafka.clients.admin.AdminClient
import org.apache.kafka.clients.consumer.ConsumerRecord
import org.apache.kafka.clients.consumer.KafkaConsumer
import collection.JavaConverters._

val perfTopic = "reordered_perf_customers"
val perfGroup = "reordered-e2e-performance"
val perfClient = "consumer-reordered-e2e-performance"
val orderedPerfTopic = "reordered_perf_customers_ordered"
val orderedPerfGroup = "reordered-e2e-performance-ordered"
val orderedPerfClient = "consumer-reordered-e2e-performance-ordered"
val kafkaPerfTopic = "reordered_perf_customers_kafka"
val kafkaPerfGroup = "normal-e2e-performance"
val kafkaPerfClient = "consumer-normal-e2e-performance"
val baselineLabel = sys.env.getOrElse("REORDERED_PERF_BASELINE_LABEL", "ksi-baseline")
val orderedLabel = sys.env.getOrElse("REORDERED_PERF_ORDERED_LABEL", "ksi-ordered-coldset")
val targetRecords = sys.env.get("REORDERED_PERF_TARGET_RECORDS").map(_.toInt).getOrElse(1000000)
val ksiMaxPollRecords = sys.env.get("REORDERED_PERF_KSI_MAX_POLL_RECORDS").map(_.toInt).getOrElse(50000)
val kafkaMaxPollRecords = sys.env.get("REORDERED_PERF_KAFKA_MAX_POLL_RECORDS").map(_.toInt).getOrElse(200)
val pollTimeoutSeconds = sys.env.get("REORDERED_PERF_POLL_TIMEOUT_SECONDS").map(_.toInt).getOrElse(30)
val emptyPollLimit = sys.env.get("REORDERED_PERF_EMPTY_POLLS").map(_.toInt).getOrElse(3)
val selectedCaseTokens = sys.env.getOrElse("REORDERED_PERF_CASES", "ordered,baseline,kafka")

def nowTs: String = Instant.now().toString

def perfLog(label: String, message: String): Unit = {
  println(s"${nowTs} [PERF][$label] $message")
}

case class PerfResult(
  label: String,
  topic: String,
  group: String,
  totalRecords: Long,
  batchNumber: Int,
  pollCount: Int,
  emptyPolls: Int,
  firstOffset: Long,
  lastOffset: Long,
  totalElapsedMs: Long,
  avgLatency: Double,
  p50: Long,
  p95: Long,
  throughput: Double
)

case class PerfCase(
  id: String,
  label: String,
  topic: String,
  group: String,
  client: String,
  bootstrapServers: String,
  maxPollRecords: Int
)

val orderedCase = PerfCase(orderedLabel, orderedLabel, orderedPerfTopic, orderedPerfGroup, orderedPerfClient, "ksi:9192", ksiMaxPollRecords)
val baselineCase = PerfCase(baselineLabel, baselineLabel, perfTopic, perfGroup, perfClient, "ksi:9192", ksiMaxPollRecords)
val kafkaCase = PerfCase("normal-kafka", "normal-kafka", kafkaPerfTopic, kafkaPerfGroup, kafkaPerfClient, "kafka1:9092", kafkaMaxPollRecords)

val caseAliases: Map[String, PerfCase] = Map(
  "ordered" -> orderedCase,
  "ksi-ordered" -> orderedCase,
  "ordered-ksi" -> orderedCase,
  orderedPerfTopic -> orderedCase,
  orderedLabel -> orderedCase,
  "baseline" -> baselineCase,
  "ksi-baseline" -> baselineCase,
  "normal" -> baselineCase,
  "reordered" -> baselineCase,
  perfTopic -> baselineCase,
  baselineLabel -> baselineCase,
  "kafka" -> kafkaCase,
  "normal-kafka" -> kafkaCase,
  kafkaPerfTopic -> kafkaCase
)

def parseSelectedCases(raw: String): Seq[PerfCase] = {
  val tokens = raw.split(",").map(_.trim).filter(_.nonEmpty).map(_.toLowerCase)
  val expandedTokens = if (tokens.isEmpty || tokens.contains("all")) {
    Seq("ordered", "baseline", "kafka")
  } else {
    tokens.toSeq
  }

  val unknownTokens = expandedTokens.filterNot(caseAliases.contains)
  require(
    unknownTokens.isEmpty,
    s"Unknown REORDERED_PERF_CASES value(s): ${unknownTokens.mkString(", ")}. " +
      "Use ordered, baseline, kafka, all, or the concrete topic names."
  )

  expandedTokens.map(caseAliases).foldLeft(Seq.empty[PerfCase]) { (acc, perfCase) =>
    if (acc.exists(_.id == perfCase.id)) acc else acc :+ perfCase
  }
}

val selectedCases = parseSelectedCases(selectedCaseTokens)

def createAdminClient(bootstrapServers: String = "kafka1:9092"): AdminClient = {
  val adminProps = new Properties()
  adminProps.put("bootstrap.servers", bootstrapServers)
  AdminClient.create(adminProps)
}

def deleteConsumerGroup(groupId: String, bootstrapServers: String = "kafka1:9092"): Unit = {
  val admin = createAdminClient(bootstrapServers)
  try {
    admin.deleteConsumerGroups(Collections.singletonList(groupId)).all().get()
  } catch {
    case _: Throwable =>
  } finally {
    admin.close()
  }
}

def createConsumer(
  groupId: String,
  clientId: String,
  bootstrapServers: String,
  maxPollRecords: Int
): KafkaConsumer[String, Object] = {
  val consumerProps = new Properties()
  consumerProps.put("bootstrap.servers", bootstrapServers)
  consumerProps.put("group.id", groupId)
  consumerProps.put("client.id", clientId)
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

class ReorderedPerfSuite extends AnyFunSuite {
  def consumeAndReport(
    label: String,
    topic: String,
    groupId: String,
    clientId: String,
    bootstrapServers: String,
    maxPollRecords: Int
  ): PerfResult = {
    deleteConsumerGroup(groupId, bootstrapServers)

    val consumer = createConsumer(groupId, clientId, bootstrapServers, maxPollRecords)
    consumer.subscribe(Collections.singletonList(topic))

    var totalRecords = 0L
    var batchNumber = 0
    var pollCount = 0
    var emptyPolls = 0
    var totalEmptyPolls = 0
    var firstOffset = -1L
    var lastOffset = -1L
    val batchLatencies = scala.collection.mutable.ArrayBuffer.empty[Long]
    val startedAt = System.currentTimeMillis()

    while (totalRecords < targetRecords && emptyPolls < emptyPollLimit) {
      val pollStartedAt = System.currentTimeMillis()
      val records = consumer.poll(Duration.ofSeconds(pollTimeoutSeconds))
      val elapsedMs = System.currentTimeMillis() - pollStartedAt
      val topicRecords = records.records(topic).asScala.toList
      pollCount += 1

      if (topicRecords.isEmpty) {
        emptyPolls += 1
        totalEmptyPolls += 1
        perfLog(label, s"empty poll $emptyPolls/$emptyPollLimit after ${elapsedMs}ms")
      } else {
        emptyPolls = 0
        batchNumber += 1
        batchLatencies += elapsedMs
        if (firstOffset < 0) {
          firstOffset = topicRecords.head.offset()
        }
        lastOffset = topicRecords.last.offset()

        val expectedFirstOffset = totalRecords
        assert(topicRecords.head.offset() == expectedFirstOffset,
          s"Expected first offset in batch $batchNumber to be $expectedFirstOffset, got ${topicRecords.head.offset()}")

        totalRecords += topicRecords.size
        consumer.commitSync()

        perfLog(
          label,
          s"batch=$batchNumber records=${topicRecords.size} elapsedMs=$elapsedMs " +
            s"offsetRange=${topicRecords.head.offset()}-${topicRecords.last.offset()} total=$totalRecords"
        )
      }
    }

    consumer.close()

    val totalElapsedMs = System.currentTimeMillis() - startedAt
    assert(totalRecords > 0, s"Expected performance consumer to receive reordered records for topic '$topic'")
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
    println(s"REORDERED PERF SUMMARY [$label]")
    println(s"topic=$topic group=$groupId bootstrapServers=$bootstrapServers")
    println(s"consumerMaxPollRecords=$maxPollRecords")
    println(s"targetRecords=$targetRecords consumedRecords=$totalRecords batches=$batchNumber")
    println(s"polls=$pollCount nonEmptyPolls=$batchNumber emptyPolls=$totalEmptyPolls")
    println(s"firstOffset=$firstOffset lastOffset=$lastOffset")
    println(f"totalElapsedMs=$totalElapsedMs throughputRecordsPerSec=$throughput%.2f")
    println(f"batchLatencyMs avg=$avgLatency%.2f p50=$p50 p95=$p95")
    println("=" * 80)
    println("")

    PerfResult(label, topic, groupId, totalRecords, batchNumber, pollCount, totalEmptyPolls, firstOffset, lastOffset, totalElapsedMs, avgLatency, p50, p95, throughput)
  }

  test("compare reordered performance baseline and ordered coldset topics") {
    println(s"Selected performance cases: ${selectedCases.map(_.id).mkString(", ")}")

    val results = selectedCases.map { perfCase =>
      perfCase.id -> consumeAndReport(
        perfCase.label,
        perfCase.topic,
        perfCase.group,
        perfCase.client,
        perfCase.bootstrapServers,
        perfCase.maxPollRecords
      )
    }.toMap

    def speedRatio(candidate: PerfResult, reference: PerfResult): Double = {
      if (reference.throughput > 0) candidate.throughput / reference.throughput else 0.0
    }

    def slowdown(reference: PerfResult, candidate: PerfResult): Double = {
      if (candidate.throughput > 0) reference.throughput / candidate.throughput else 0.0
    }

    def printResultRow(result: PerfResult, vsKafka: Double, slowdownVsKafka: Double): Unit = {
      val recordsPerPollBatch = if (result.batchNumber > 0) result.totalRecords.toDouble / result.batchNumber else 0.0
      println(f"${result.label}%-22s ${result.topic}%-36s ${result.throughput}%14.2f ${result.totalElapsedMs}%12d ${result.pollCount}%8d ${result.batchNumber}%14d ${recordsPerPollBatch}%18.2f ${vsKafka}%10.3f ${slowdownVsKafka}%14.2f")
    }

    println("")
    println("=" * 80)
    println("REORDERED PERF COMPARISON")
    println(s"ksiConsumerMaxPollRecords=$ksiMaxPollRecords normalKafkaConsumerMaxPollRecords=$kafkaMaxPollRecords")
    println(s"selectedCases=${selectedCases.map(_.id).mkString(",")}")
    println("poll batches are non-empty KafkaConsumer.poll() responses, not internal KSI cold-storage fetches")
    println(f"${"case"}%-22s ${"topic"}%-36s ${"records/sec"}%14s ${"elapsed ms"}%12s ${"polls"}%8s ${"poll batches"}%14s ${"records/poll batch"}%18s ${"vs kafka"}%10s ${"kafka faster"}%14s")
    println("-" * 150)

    val maybeKafka = results.get("normal-kafka")
    selectedCases.foreach { perfCase =>
      val result = results(perfCase.id)
      val vsKafka = maybeKafka.map(kafka => speedRatio(result, kafka)).getOrElse(0.0)
      val kafkaFaster = maybeKafka.map(kafka => slowdown(kafka, result)).getOrElse(0.0)
      printResultRow(result, vsKafka, kafkaFaster)
    }

    println("-" * 150)

    for {
      ordered <- results.get(orderedLabel)
      baseline <- results.get(baselineLabel)
    } {
      val orderedVsBaseline = speedRatio(ordered, baseline)
      println(f"$orderedLabel vs $baselineLabel: ${orderedVsBaseline}%.3fx throughput (${(orderedVsBaseline - 1.0) * 100.0}%.1f%%)")
    }

    for {
      baseline <- results.get(baselineLabel)
      kafka <- maybeKafka
    } {
      val baselineVsKafka = speedRatio(baseline, kafka)
      println(f"$baselineLabel vs Kafka: ${baselineVsKafka}%.3fx throughput (${slowdown(kafka, baseline)}%.2fx slower)")
    }

    for {
      ordered <- results.get(orderedLabel)
      kafka <- maybeKafka
    } {
      val orderedVsKafka = speedRatio(ordered, kafka)
      println(f"$orderedLabel vs Kafka:  ${orderedVsKafka}%.3fx throughput (${slowdown(kafka, ordered)}%.2fx slower)")
    }

    if (maybeKafka.isEmpty) {
      println("Kafka baseline was not selected; vs kafka columns are 0.000.")
    }

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
