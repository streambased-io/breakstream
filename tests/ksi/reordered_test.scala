import org.scalatest.funsuite.AnyFunSuite
import org.scalatest.Args

/*
Verify reordered consumer groups for KSI using a dedicated reordered_customers topic.
*/
import java.time.Duration
import java.util.Properties
import java.util.Collections
import org.apache.avro.generic.GenericRecord
import org.apache.kafka.clients.admin.AdminClient
import org.apache.kafka.clients.consumer.ConsumerRecord
import org.apache.kafka.clients.consumer.ConsumerRecords
import org.apache.kafka.clients.consumer.KafkaConsumer
import collection.JavaConverters._
import org.scalatest.Assertions.fail

val reorderedTopic = "reordered_customers"
val reorderedMatchName = "Reordered Match"
val firstConsumeGroup = "reordered-e2e-first-consume"
val resumeGroup = "reordered-e2e-resume"
val firstConsumeClient = "consumer-reordered-e2e-first-consume"
val resumeClient = "consumer-reordered-e2e-resume"
val normalClient = "consumer-normal-reordered-check"
val pollTimeoutSeconds = 15

def createConsumer(
  bootstrapServers: String,
  groupId: String,
  clientId: String,
  maxPollRecords: Int = 10
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

def pollUntilNonEmpty(
  consumer: KafkaConsumer[String, Object],
  topic: String,
  timeoutSeconds: Int = pollTimeoutSeconds
): ConsumerRecords[String, Object] = {
  val startedAt = System.currentTimeMillis()
  var records = consumer.poll(Duration.ofSeconds(2))
  while (records.records(topic).asScala.isEmpty && (System.currentTimeMillis() - startedAt) < timeoutSeconds * 1000L) {
    records = consumer.poll(Duration.ofSeconds(2))
  }
  if (records.records(topic).asScala.isEmpty) {
    fail(s"Timed out after ${timeoutSeconds}s waiting for records on topic '$topic'")
  }
  records
}

def collectAtMostTopicRecords(
  consumer: KafkaConsumer[String, Object],
  topic: String,
  expectedMaxRecords: Int,
  timeoutSeconds: Int = pollTimeoutSeconds
): List[ConsumerRecord[String, Object]] = {
  val startedAt = System.currentTimeMillis()
  val collected = scala.collection.mutable.ArrayBuffer.empty[ConsumerRecord[String, Object]]
  while (collected.size < expectedMaxRecords && (System.currentTimeMillis() - startedAt) < timeoutSeconds * 1000L) {
    val records = consumer.poll(Duration.ofSeconds(2))
    val topicRecords = records.records(topic).asScala.toList
    if (topicRecords.nonEmpty) {
      collected ++= topicRecords
    }
  }
  if (collected.isEmpty) {
    fail(s"Timed out after ${timeoutSeconds}s waiting for records on topic '$topic'")
  }
  collected.toList
}

def recordName(record: ConsumerRecord[String, Object]): String = {
  record.value().asInstanceOf[GenericRecord].get("Name").toString
}

class ReorderedKsiSuite extends AnyFunSuite {
  test("reordered group returns only filtered records with synthetic monotonic offsets") {
    deleteConsumerGroup(firstConsumeGroup)
    val consumer = createConsumer("ksi:9192", firstConsumeGroup, firstConsumeClient, maxPollRecords = 10)
    consumer.subscribe(Collections.singletonList(reorderedTopic))
    val records = collectAtMostTopicRecords(consumer, reorderedTopic, expectedMaxRecords = 4)
    consumer.close()

    assert(records.nonEmpty, "Expected reordered consumer to receive filtered records")
    assert(records.forall(recordName(_) == reorderedMatchName),
      s"Expected all reordered records to match Name='$reorderedMatchName' but got: ${records.map(recordName).distinct}")

    val offsets = records.map(_.offset())
    assert(offsets == offsets.indices.map(_.toLong).toList,
      s"Expected synthetic monotonic offsets starting at 0, got: $offsets")
    assert(records.length == 4, s"Expected 4 filtered reordered records, got ${records.length}")
  }

  test("reordered group commit and resume continues from the next synthetic offset without duplicates") {
    deleteConsumerGroup(resumeGroup)

    val consumer1 = createConsumer("ksi:9192", resumeGroup, resumeClient, maxPollRecords = 2)
    consumer1.subscribe(Collections.singletonList(reorderedTopic))
    val firstBatch = pollUntilNonEmpty(consumer1, reorderedTopic)
    val phase1Records = firstBatch.records(reorderedTopic).asScala.toList
    assert(phase1Records.nonEmpty, "Expected first phase to consume reordered records")
    assert(phase1Records.forall(recordName(_) == reorderedMatchName),
      s"Expected reordered phase 1 records to match Name='$reorderedMatchName'")
    val lastOffset = phase1Records.last.offset()
    consumer1.commitSync()
    consumer1.close()

    val consumer2 = createConsumer("ksi:9192", resumeGroup, resumeClient, maxPollRecords = 10)
    consumer2.subscribe(Collections.singletonList(reorderedTopic))
    val resumedBatch = pollUntilNonEmpty(consumer2, reorderedTopic)
    val resumedRecords = resumedBatch.records(reorderedTopic).asScala.toList
    consumer2.close()

    assert(resumedRecords.nonEmpty, "Expected resumed consumer to receive remaining reordered records")
    assert(resumedRecords.head.offset() == lastOffset + 1,
      s"Expected resumed consumer to continue from ${lastOffset + 1}, got ${resumedRecords.head.offset()}")
    assert(resumedRecords.forall(recordName(_) == reorderedMatchName),
      s"Expected resumed reordered records to match Name='$reorderedMatchName'")
    assert(!resumedRecords.exists(_.offset() <= lastOffset),
      s"Expected no duplicate offsets after resume; last committed offset was $lastOffset, got ${resumedRecords.map(_.offset())}")
  }

  test("normal group on the same topic remains unfiltered") {
    val normalGroup = "normal-reordered-check"
    deleteConsumerGroup(normalGroup)

    val consumer = createConsumer("ksi:9192", normalGroup, normalClient, maxPollRecords = 25)
    consumer.subscribe(Collections.singletonList(reorderedTopic))
    val records = collectAtMostTopicRecords(consumer, reorderedTopic, expectedMaxRecords = 5)
    consumer.close()

    assert(records.nonEmpty, "Expected normal consumer to receive records from reordered_customers")
    val names = records.map(recordName)
    assert(names.contains(reorderedMatchName), "Expected normal consumer to include the matching record as part of the full topic")
    assert(names.exists(_ != reorderedMatchName),
      s"Expected normal consumer to remain unfiltered and include non-matching names, got only: ${names.distinct}")
  }
}

val reporter = new TestReporter
try {
  (new ReorderedKsiSuite).run(None, new Args(reporter = reporter))
} catch {
  case e: Throwable => {
    e.printStackTrace()
    println(e)
  }
} finally {
  reporter.printSummary()
  if (reporter.failed > 0) System.exit(1) else System.exit(0)
}
