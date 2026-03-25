import org.scalatest.funsuite.AnyFunSuite
import org.scalatest.Args

/*
Verify Hyperstream Functions - UPPER, UPPER(TRIM), and Plain Field Index
*/
import sttp.client4.quick._
import scala.concurrent.duration._
import net.liftweb.json._
implicit val formats = net.liftweb.json.DefaultFormats

class HyperstreamSuite extends AnyFunSuite {
  // ==========================================
  // UPPER Transformer Tests
  // ==========================================
  test("creates transformer index with UPPER function") {
    val transformerIndexRequest = Serialization.write(Map(
      "topic" -> "customers",
      "field" -> "Name",
      "transformerFunction" -> "UPPER($field)"
    ))
    val transformerIndexResponse = quickRequest.readTimeout(5.minutes).put(uri"http://hyperstream:9088/api/index").auth.basic("sbpk_12345678", "sbsk_12345678").body(transformerIndexRequest).send()
    assert(transformerIndexResponse.code.code == 200, s"Create UPPER transformer index failed: expected 200 but got ${transformerIndexResponse.code.code}, body: ${transformerIndexResponse.body}")
  }

  test("enriches query with UPPER transformer function") {
    case class EnrichedResponse(originalSql:String, enrichedSql:String)
    val enrichRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE UPPER(Name) = 'JUDITH GOTTLIEB STREAMBASED1'"
    ))
    val enrichResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/enrich").auth.basic("sbpk_12345678", "sbsk_12345678").body(enrichRequest).send()
    assert(enrichResponse.code.code == 200, s"UPPER enrich request failed: expected 200 but got ${enrichResponse.code.code}, body: ${enrichResponse.body}")
    val parsed = parse(enrichResponse.body)
    val enrichedResponseObj = parsed.extract[EnrichedResponse]
    assert(enrichedResponseObj.enrichedSql == "SELECT * FROM (SELECT *  FROM customers WHERE (( kafka_partition = 0 AND kafka_offset >= 333000 AND kafka_offset < 334000)) OR  (( kafka_partition = 0 AND kafka_offset >= 999999 )))  WHERE UPPER(Name) = 'JUDITH GOTTLIEB STREAMBASED1'", s"UPPER enrichedSql mismatch: ${enrichedResponseObj.enrichedSql}")
  }

  test("performance improvement with UPPER transformer index") {
    val unindexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE UPPER(Name) = 'JUDITH GOTTLIEB STREAMBASED1'",
      "index" -> false,
      "set" -> "UNIFIED"
    ))
    val unindexedStart = System.currentTimeMillis()
    val unindexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(unindexedRequest).send()
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedResponse.code.code == 200, s"UPPER unindexed query failed: expected 200 but got ${unindexedResponse.code.code}, body: ${unindexedResponse.body}")
    val indexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE UPPER(Name) = 'JUDITH GOTTLIEB STREAMBASED1'",
      "index" -> true,
      "set" -> "UNIFIED"
    ))
    val indexedStart = System.currentTimeMillis()
    val indexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(indexedRequest).send()
    val indexedEnd = System.currentTimeMillis()
    assert(indexedResponse.code.code == 200, s"UPPER indexed query failed: expected 200 but got ${indexedResponse.code.code}, body: ${indexedResponse.body}")
    assert(unindexedResponse.body == indexedResponse.body, s"UPPER indexed and unindexed results differ.\nUnindexed: ${unindexedResponse.body.take(500)}\nIndexed: ${indexedResponse.body.take(500)}")
    val unindexedDuration = unindexedEnd - unindexedStart
    val indexedDuration = indexedEnd - indexedStart
//    assert(indexedDuration < (unindexedDuration / 2), s"UPPER 2x speedup not achieved: unindexed=${unindexedDuration}ms, indexed=${indexedDuration}ms, ratio=${unindexedDuration.toDouble/indexedDuration}")
  }

  test("enriches plain field query using UPPER index as superset match") {
    case class EnrichedResponse(originalSql:String, enrichedSql:String)
    val enrichRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'"
    ))
    val enrichResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/enrich").auth.basic("sbpk_12345678", "sbsk_12345678").body(enrichRequest).send()
    assert(enrichResponse.code.code == 200, s"Plain field enrich (UPPER superset) failed: expected 200 but got ${enrichResponse.code.code}, body: ${enrichResponse.body}")
    val parsed = parse(enrichResponse.body)
    val enrichedResponseObj = parsed.extract[EnrichedResponse]
    assert(enrichedResponseObj.enrichedSql == "SELECT * FROM (SELECT *  FROM customers WHERE (( kafka_partition = 0 AND kafka_offset >= 333000 AND kafka_offset < 334000)) OR  (( kafka_partition = 0 AND kafka_offset >= 999999 )))  WHERE Name = 'Judith Gottlieb Streambased1'", s"Plain field enrichedSql (UPPER superset) mismatch: ${enrichedResponseObj.enrichedSql}")
  }

  test("performance improvement with plain field query using UPPER index as superset match") {
    val unindexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'",
      "index" -> false,
      "set" -> "UNIFIED"
    ))
    val unindexedStart = System.currentTimeMillis()
    val unindexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(unindexedRequest).send()
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedResponse.code.code == 200, s"Plain field unindexed query (UPPER superset) failed: expected 200 but got ${unindexedResponse.code.code}, body: ${unindexedResponse.body}")
    val indexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'",
      "index" -> true,
      "set" -> "UNIFIED"
    ))
    val indexedStart = System.currentTimeMillis()
    val indexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(indexedRequest).send()
    val indexedEnd = System.currentTimeMillis()
    assert(indexedResponse.code.code == 200, s"Plain field indexed query (UPPER superset) failed: expected 200 but got ${indexedResponse.code.code}, body: ${indexedResponse.body}")
    assert(unindexedResponse.body == indexedResponse.body, s"Plain field indexed and unindexed results differ (UPPER superset).\nUnindexed: ${unindexedResponse.body.take(500)}\nIndexed: ${indexedResponse.body.take(500)}")
    assert(indexedResponse.body.contains("Judith Gottlieb Streambased1"), s"Plain field indexed query result does not contain 'Judith Gottlieb Streambased1': ${indexedResponse.body.take(500)}")
    val unindexedDuration = unindexedEnd - unindexedStart
    val indexedDuration = indexedEnd - indexedStart
//    assert(indexedDuration < (unindexedDuration / 2), s"Plain field (UPPER superset) 2x speedup not achieved: unindexed=${unindexedDuration}ms, indexed=${indexedDuration}ms, ratio=${unindexedDuration.toDouble/indexedDuration}")
  }
  // ==========================================
  // UPPER(TRIM) Nested Transformer Tests
  // ==========================================
  test("creates transformer index with nested UPPER(TRIM) function") {
    val transformerIndexRequest = Serialization.write(Map(
      "topic" -> "customers",
      "field" -> "Name",
      "transformerFunction" -> "UPPER(TRIM($field))"
    ))
    val transformerIndexResponse = quickRequest.readTimeout(5.minutes).put(uri"http://hyperstream:9088/api/index").auth.basic("sbpk_12345678", "sbsk_12345678").body(transformerIndexRequest).send()
    assert(transformerIndexResponse.code.code == 200, s"Create nested transformer index failed: expected 200 but got ${transformerIndexResponse.code.code}, body: ${transformerIndexResponse.body}")
  }

  test("enriches query with nested UPPER(TRIM) transformer function") {
    case class EnrichedResponse(originalSql:String, enrichedSql:String)
    val enrichRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE UPPER(TRIM(Name)) = 'JUDITH GOTTLIEB STREAMBASED1'"
    ))
    val enrichResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/enrich").auth.basic("sbpk_12345678", "sbsk_12345678").body(enrichRequest).send()
    assert(enrichResponse.code.code == 200, s"UPPER(TRIM) enrich request failed: expected 200 but got ${enrichResponse.code.code}, body: ${enrichResponse.body}")
    val parsed = parse(enrichResponse.body)
    val enrichedResponseObj = parsed.extract[EnrichedResponse]
    assert(!enrichedResponseObj.enrichedSql.equals(enrichedResponseObj.originalSql), s"UPPER(TRIM) enrichment not applied: enrichedSql equals originalSql: ${enrichedResponseObj.enrichedSql}")
    assert(enrichedResponseObj.enrichedSql.contains("kafka_partition"), s"UPPER(TRIM) enrichedSql missing kafka_partition: ${enrichedResponseObj.enrichedSql}")
  }

  test("performance improvement with nested UPPER(TRIM) transformer index") {
    val unindexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE UPPER(TRIM(Name)) = 'JUDITH GOTTLIEB STREAMBASED1'",
      "index" -> false,
      "set" -> "UNIFIED"
    ))
    val unindexedStart = System.currentTimeMillis()
    val unindexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(unindexedRequest).send()
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedResponse.code.code == 200, s"UPPER(TRIM) unindexed query failed: expected 200 but got ${unindexedResponse.code.code}, body: ${unindexedResponse.body}")
    val indexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE UPPER(TRIM(Name)) = 'JUDITH GOTTLIEB STREAMBASED1'",
      "index" -> true,
      "set" -> "UNIFIED"
    ))
    val indexedStart = System.currentTimeMillis()
    val indexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(indexedRequest).send()
    val indexedEnd = System.currentTimeMillis()
    assert(indexedResponse.code.code == 200, s"UPPER(TRIM) indexed query failed: expected 200 but got ${indexedResponse.code.code}, body: ${indexedResponse.body}")
    assert(unindexedResponse.body == indexedResponse.body, s"UPPER(TRIM) indexed and unindexed results differ.\nUnindexed: ${unindexedResponse.body.take(500)}\nIndexed: ${indexedResponse.body.take(500)}")
    val unindexedDuration = unindexedEnd - unindexedStart
    val indexedDuration = indexedEnd - indexedStart
    assert(indexedDuration < (unindexedDuration / 2), s"UPPER(TRIM) 2x speedup not achieved: unindexed=${unindexedDuration}ms, indexed=${indexedDuration}ms, ratio=${unindexedDuration.toDouble/indexedDuration}")
  }
  // ==========================================
  // Plain Field Index Tests
  // ==========================================
  test("creates index on plain field (no transformer)") {
    val indexCreateRequest = Serialization.write(Map(
      "topic" -> "customers",
      "field" -> "Name"
    ))
    val indexCreateResponse = quickRequest.readTimeout(5.minutes).put(uri"http://hyperstream:9088/api/index").auth.basic("sbpk_12345678", "sbsk_12345678").body(indexCreateRequest).send()
    assert(indexCreateResponse.code.code == 200, s"Create plain field index failed: expected 200 but got ${indexCreateResponse.code.code}, body: ${indexCreateResponse.body}")
  }

  test("enriches plain field query using exact match index") {
    case class EnrichedResponse(originalSql:String, enrichedSql:String)
    val enrichRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'"
    ))
    val enrichResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/enrich").auth.basic("sbpk_12345678", "sbsk_12345678").body(enrichRequest).send()
    assert(enrichResponse.code.code == 200, s"Plain field enrich (exact match) failed: expected 200 but got ${enrichResponse.code.code}, body: ${enrichResponse.body}")
    val parsed = parse(enrichResponse.body)
    val enrichedResponseObj = parsed.extract[EnrichedResponse]
    assert(!enrichedResponseObj.enrichedSql.equals(enrichedResponseObj.originalSql), s"Plain field enrichment not applied (exact match): enrichedSql equals originalSql: ${enrichedResponseObj.enrichedSql}")
    assert(enrichedResponseObj.enrichedSql.contains("kafka_partition"), s"Plain field enrichedSql missing kafka_partition (exact match): ${enrichedResponseObj.enrichedSql}")
  }

  test("performance improvement with plain field exact match index") {
    val unindexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'",
      "index" -> false,
      "set" -> "UNIFIED"
    ))
    val unindexedStart = System.currentTimeMillis()
    val unindexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(unindexedRequest).send()
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedResponse.code.code == 200, s"Plain field unindexed query (exact match) failed: expected 200 but got ${unindexedResponse.code.code}, body: ${unindexedResponse.body}")
    val indexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'",
      "index" -> true,
      "set" -> "UNIFIED"
    ))
    val indexedStart = System.currentTimeMillis()
    val indexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(indexedRequest).send()
    val indexedEnd = System.currentTimeMillis()
    assert(indexedResponse.code.code == 200, s"Plain field indexed query (exact match) failed: expected 200 but got ${indexedResponse.code.code}, body: ${indexedResponse.body}")
    assert(unindexedResponse.body == indexedResponse.body, s"Plain field indexed and unindexed results differ (exact match).\nUnindexed: ${unindexedResponse.body.take(500)}\nIndexed: ${indexedResponse.body.take(500)}")
    assert(indexedResponse.body.contains("Judith Gottlieb Streambased1"), s"Plain field indexed query result does not contain 'Judith Gottlieb Streambased1': ${indexedResponse.body.take(500)}")
    val unindexedDuration = unindexedEnd - unindexedStart
    val indexedDuration = indexedEnd - indexedStart
    assert(indexedDuration < (unindexedDuration / 2), s"Plain field (exact match) 2x speedup not achieved: unindexed=${unindexedDuration}ms, indexed=${indexedDuration}ms, ratio=${unindexedDuration.toDouble/indexedDuration}")
  }
}

// run tests
try {
  (new HyperstreamSuite).run(None, new Args(reporter = new TestReporter))
} catch {
  case e: Throwable => {
    e.printStackTrace()
    println(e)
    System.exit(1)
  }
} finally {
  System.exit(0)
}
