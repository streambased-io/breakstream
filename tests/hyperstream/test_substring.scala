import org.scalatest.funsuite.AnyFunSuite
import org.scalatest.Args

/*
Verify Hyperstream SUBSTRING Transformer Functions
*/
import sttp.client4.quick._
import scala.concurrent.duration._
import net.liftweb.json._
implicit val formats = net.liftweb.json.DefaultFormats

class SubstringSuite extends AnyFunSuite {
  // ==========================================
  // SUBSTRING Transformer Tests
  // ==========================================
  test("creates transformer index with SUBSTRING function") {
    val transformerIndexRequest = Serialization.write(Map(
      "topic" -> "customers",
      "field" -> "Name",
      "transformerFunction" -> "SUBSTRING($field, 1, 27)"
    ))
    val transformerIndexResponse = quickRequest.readTimeout(5.minutes).put(uri"http://hyperstream:9088/api/index").auth.basic("sbpk_12345678", "sbsk_12345678").body(transformerIndexRequest).send()
    assert(transformerIndexResponse.code.code == 200, s"Create SUBSTRING transformer index failed: expected 200 but got ${transformerIndexResponse.code.code}, body: ${transformerIndexResponse.body}")
  }

  test("enriches query with SUBSTRING transformer function") {
    case class EnrichedResponse(originalSql:String, enrichedSql:String)
    val enrichRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE SUBSTRING(Name, 1, 27) = 'Judith Gottlieb Streambased'"
    ))
    val enrichResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/enrich").auth.basic("sbpk_12345678", "sbsk_12345678").body(enrichRequest).send()
    assert(enrichResponse.code.code == 200, s"SUBSTRING enrich request failed: expected 200 but got ${enrichResponse.code.code}, body: ${enrichResponse.body}")
    val parsed = parse(enrichResponse.body)
    val enrichedResponseObj = parsed.extract[EnrichedResponse]
    assert(enrichedResponseObj.enrichedSql == "SELECT * FROM (SELECT *  FROM customers WHERE (( kafka_partition = 0 AND kafka_offset >= 333000 AND kafka_offset < 334000) OR ( kafka_partition = 0 AND kafka_offset >= 663000 AND kafka_offset < 664000)) OR  (( kafka_partition = 0 AND kafka_offset >= 999999 )))  WHERE SUBSTRING(Name, 1, 27) = 'Judith Gottlieb Streambased'", s"SUBSTRING enrichedSql mismatch: ${enrichedResponseObj.enrichedSql}")
  }

  test("performance improvement with SUBSTRING transformer index") {
    val unindexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE SUBSTRING(Name, 1, 27) = 'Judith Gottlieb Streambased'",
      "index" -> false,
      "set" -> "UNIFIED"
    ))
    val unindexedStart = System.currentTimeMillis()
    val unindexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(unindexedRequest).send()
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedResponse.code.code == 200, s"SUBSTRING unindexed query failed: expected 200 but got ${unindexedResponse.code.code}, body: ${unindexedResponse.body}")
    val indexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE SUBSTRING(Name, 1, 27) = 'Judith Gottlieb Streambased'",
      "index" -> true,
      "set" -> "UNIFIED"
    ))
    val indexedStart = System.currentTimeMillis()
    val indexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(indexedRequest).send()
    val indexedEnd = System.currentTimeMillis()
    assert(indexedResponse.code.code == 200, s"SUBSTRING indexed query failed: expected 200 but got ${indexedResponse.code.code}, body: ${indexedResponse.body}")
    assert(unindexedResponse.body == indexedResponse.body, s"SUBSTRING indexed and unindexed results differ.\nUnindexed: ${unindexedResponse.body.take(500)}\nIndexed: ${indexedResponse.body.take(500)}")
    val unindexedDuration = unindexedEnd - unindexedStart
    val indexedDuration = indexedEnd - indexedStart
    assert(indexedDuration < (unindexedDuration / 2), s"SUBSTRING 2x speedup not achieved: unindexed=${unindexedDuration}ms, indexed=${indexedDuration}ms, ratio=${unindexedDuration.toDouble/indexedDuration}")
  }

  test("enriches plain field query using SUBSTRING index as superset match") {
    case class EnrichedResponse(originalSql:String, enrichedSql:String)
    val enrichRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'"
    ))
    val enrichResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/enrich").auth.basic("sbpk_12345678", "sbsk_12345678").body(enrichRequest).send()
    assert(enrichResponse.code.code == 200, s"Plain field enrich (SUBSTRING superset) failed: expected 200 but got ${enrichResponse.code.code}, body: ${enrichResponse.body}")
    val parsed = parse(enrichResponse.body)
    val enrichedResponseObj = parsed.extract[EnrichedResponse]
    assert(enrichedResponseObj.enrichedSql == "SELECT * FROM (SELECT *  FROM customers WHERE (( kafka_partition = 0 AND kafka_offset >= 333000 AND kafka_offset < 334000) OR ( kafka_partition = 0 AND kafka_offset >= 663000 AND kafka_offset < 664000)) OR  (( kafka_partition = 0 AND kafka_offset >= 999999 )))  WHERE Name = 'Judith Gottlieb Streambased1'", s"Plain field enrichedSql (SUBSTRING superset) mismatch: ${enrichedResponseObj.enrichedSql}")
  }

  test("performance improvement with plain field query using SUBSTRING index as superset match") {
    val unindexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'",
      "index" -> false,
      "set" -> "UNIFIED"
    ))
    val unindexedStart = System.currentTimeMillis()
    val unindexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(unindexedRequest).send()
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedResponse.code.code == 200, s"Plain field unindexed query failed: expected 200 but got ${unindexedResponse.code.code}, body: ${unindexedResponse.body}")
    val indexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'",
      "index" -> true,
      "set" -> "UNIFIED"
    ))
    val indexedStart = System.currentTimeMillis()
    val indexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(indexedRequest).send()
    val indexedEnd = System.currentTimeMillis()
    assert(indexedResponse.code.code == 200, s"Plain field indexed query (SUBSTRING superset) failed: expected 200 but got ${indexedResponse.code.code}, body: ${indexedResponse.body}")
    assert(unindexedResponse.body == indexedResponse.body, s"Plain field indexed and unindexed results differ (SUBSTRING superset).\nUnindexed: ${unindexedResponse.body.take(500)}\nIndexed: ${indexedResponse.body.take(500)}")
    assert(indexedResponse.body.contains("Judith Gottlieb Streambased1"), s"Plain field indexed query result does not contain 'Judith Gottlieb Streambased1': ${indexedResponse.body.take(500)}")
    val unindexedDuration = unindexedEnd - unindexedStart
    val indexedDuration = indexedEnd - indexedStart
    assert(indexedDuration < (unindexedDuration / 2), s"Plain field (SUBSTRING superset) 2x speedup not achieved: unindexed=${unindexedDuration}ms, indexed=${indexedDuration}ms, ratio=${unindexedDuration.toDouble/indexedDuration}")
  }
}

// run tests
try {
  (new SubstringSuite).run(None, new Args(reporter = new TestReporter))
} catch {
  case e: Throwable => {
    e.printStackTrace()
    println(e)
    System.exit(1)
  }
} finally {
  System.exit(0)
}
