import org.scalatest.FunSuite
import org.scalatest.Args

/*
Verify Hyperstream Functions
*/
import sttp.client4.quick._
import scala.concurrent.duration._
import net.liftweb.json._
implicit val formats = net.liftweb.json.DefaultFormats

class HyperstreamSuite extends FunSuite {
  test("creates index and uses it") {

    // let's create an index
    val indexCreateRequest = Serialization.write(Map(
      "topic" -> "customers",
      "field" -> "Name"
    ))
    val indexCreateResponse = quickRequest.readTimeout(5.minutes).put(uri"http://hyperstream:9088/api/index").auth.basic("sbpk_12345678", "sbsk_12345678").body(indexCreateRequest).send()
    assert(indexCreateResponse.code.code == 200, s"Create index failed: expected 200 but got ${indexCreateResponse.code.code}, body: ${indexCreateResponse.body}")
    // now check enrichment
    val enrichRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb'"
    ))
    val enrichResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/enrich").auth.basic("sbpk_12345678", "sbsk_12345678").body(enrichRequest).send()
    assert(enrichResponse.code.code == 200, s"Enrich request failed: expected 200 but got ${enrichResponse.code.code}, body: ${enrichResponse.body}")
    case class EnrichedResponse(originalSql:String, enrichedSql:String)

    val parsed = parse(enrichResponse.body)
    val enrichedResponseObj = parsed.extract[EnrichedResponse]
    assert(enrichedResponseObj.originalSql == "SELECT * FROM customers WHERE Name = 'Judith Gottlieb'", s"originalSql mismatch: got '${enrichedResponseObj.originalSql}'")
    //TODO: need to review this, since data is random
    assert(enrichedResponseObj.enrichedSql == "SELECT * FROM (SELECT *  FROM customers WHERE (( kafka_partition = 0 AND kafka_offset >= 334000 AND kafka_offset < 335000)) OR  (( kafka_partition = 0 AND kafka_offset >= 999999 )))  WHERE Name = 'Judith Gottlieb'")
    // time execution
    val unindexedQueryRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb'",
      "index" -> false,
      "set" -> "UNIFIED"
    ))
    val unindexedStartTime = System.currentTimeMillis()
    val unindexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(unindexedQueryRequest).send()
    val unindexedEndTime = System.currentTimeMillis()
    assert(unindexedResponse.code.code == 200, s"Unindexed query failed: expected 200 but got ${unindexedResponse.code.code}, body: ${unindexedResponse.body}")
    val indexedQueryRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb'",
      "index" -> true,
      "set" -> "UNIFIED"
    ))
    val indexedStartTime = System.currentTimeMillis()
    val indexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(indexedQueryRequest).send()
    val indexedEndTime = System.currentTimeMillis()
    assert(indexedResponse.code.code == 200, s"Indexed query failed: expected 200 but got ${indexedResponse.code.code}, body: ${indexedResponse.body}")

    // should produce the same result and that it contains the searched value
    assert(unindexedResponse.body == indexedResponse.body, s"Indexed and unindexed query results differ.\nUnindexed: ${unindexedResponse.body.take(500)}\nIndexed: ${indexedResponse.body.take(500)}")
    assert(indexedResponse.body.contains("Judith Gottlieb"), s"Indexed query result does not contain 'Judith Gottlieb': ${indexedResponse.body.take(500)}")

    val unindexDuration  = unindexedEndTime - unindexedStartTime
    val indexDuration  = indexedEndTime - indexedStartTime

    // assert 3x speedup
    assert(indexDuration < (unindexDuration/3), s"3x speedup not achieved: unindexed=${unindexDuration}ms, indexed=${indexDuration}ms, ratio=${unindexDuration.toDouble/indexDuration}")
  }

  test("creates transformer index with UPPER function") {
    val transformerIndexRequest = Serialization.write(Map(
      "topic" -> "customers",
      "field" -> "Name",
      "transformerFunction" -> "UPPER($field)"
    ))
    val transformerIndexResponse = quickRequest.readTimeout(5.minutes).put(uri"http://hyperstream:9088/api/index").auth.basic("sbpk_12345678", "sbsk_12345678").body(transformerIndexRequest).send()
    assert(transformerIndexResponse.code.code == 200, s"Create transformer index failed: expected 200 but got ${transformerIndexResponse.code.code}, body: ${transformerIndexResponse.body}")
  }

  test("enriches query with UPPER transformer function") {
    case class EnrichedResponse(originalSql:String, enrichedSql:String)

    val enrichRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE UPPER(Name) = 'JUDITH GOTTLIEB'"
    ))
    val enrichResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/enrich").auth.basic("sbpk_12345678", "sbsk_12345678").body(enrichRequest).send()
    println("CHRIS " +  enrichResponse)
    assert(enrichResponse.code.code == 200, s"UPPER enrich request failed: expected 200 but got ${enrichResponse.code.code}, body: ${enrichResponse.body}")

    val parsed = parse(enrichResponse.body)
    val enrichedResponseObj = parsed.extract[EnrichedResponse]
    // Verify enrichment was applied (SQL should be different from original)
    assert(!enrichedResponseObj.enrichedSql.equals(enrichedResponseObj.originalSql), s"UPPER enrichment not applied: enrichedSql equals originalSql: ${enrichedResponseObj.enrichedSql}")
    // Verify the transformer index was used
    assert(enrichedResponseObj.enrichedSql.contains("kafka_partition"), s"UPPER enrichedSql missing kafka_partition: ${enrichedResponseObj.enrichedSql}")
  }

  test("executes query with UPPER transformer index") {
    val queryRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE UPPER(Name) = 'JUDITH GOTTLIEB'",
      "index" -> true,
      "set" -> "UNIFIED"
    ))
    val queryResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(queryRequest).send()
    assert(queryResponse.code.code == 200, s"UPPER indexed query failed: expected 200 but got ${queryResponse.code.code}, body: ${queryResponse.body}")
  }

  test("performance improvement with UPPER transformer index") {
    // Unindexed query (full scan)
    val unindexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE UPPER(Name) = 'JUDITH GOTTLIEB'",
      "index" -> false,
      "set" -> "UNIFIED"
    ))
    val unindexedStart = System.currentTimeMillis()
    val unindexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(unindexedRequest).send()
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedResponse.code.code == 200, s"UPPER unindexed query failed: expected 200 but got ${unindexedResponse.code.code}, body: ${unindexedResponse.body}")

    // Indexed query (using transformer index)
    val indexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE UPPER(Name) = 'JUDITH GOTTLIEB'",
      "index" -> true,
      "set" -> "UNIFIED"
    ))
    val indexedStart = System.currentTimeMillis()
    val indexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(indexedRequest).send()
    val indexedEnd = System.currentTimeMillis()
    assert(indexedResponse.code.code == 200, s"UPPER indexed perf query failed: expected 200 but got ${indexedResponse.code.code}, body: ${indexedResponse.body}")

    // Both queries should return the same results
    assert(unindexedResponse.body == indexedResponse.body, s"UPPER indexed and unindexed results differ.\nUnindexed: ${unindexedResponse.body.take(500)}\nIndexed: ${indexedResponse.body.take(500)}")

    val unindexedDuration = unindexedEnd - unindexedStart
    val indexedDuration = indexedEnd - indexedStart

    // Indexed query should be faster (expect 3x speedup)
    assert(indexedDuration < (unindexedDuration / 3), s"UPPER 3x speedup not achieved: unindexed=${unindexedDuration}ms, indexed=${indexedDuration}ms, ratio=${unindexedDuration.toDouble/indexedDuration}")
  }

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
      "sql" -> "SELECT * FROM customers WHERE UPPER(TRIM(Name)) = 'JUDITH GOTTLIEB'"
    ))
    val enrichResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/enrich").auth.basic("sbpk_12345678", "sbsk_12345678").body(enrichRequest).send()
    assert(enrichResponse.code.code == 200, s"UPPER(TRIM) enrich request failed: expected 200 but got ${enrichResponse.code.code}, body: ${enrichResponse.body}")

    val parsed = parse(enrichResponse.body)
    val enrichedResponseObj = parsed.extract[EnrichedResponse]
    assert(enrichedResponseObj.originalSql == "SELECT * FROM customers WHERE UPPER(TRIM(Name)) = 'JUDITH GOTTLIEB'", s"UPPER(TRIM) originalSql mismatch: got '${enrichedResponseObj.originalSql}'")
    assert(!enrichedResponseObj.enrichedSql.equals(enrichedResponseObj.originalSql), s"UPPER(TRIM) enrichment not applied: enrichedSql equals originalSql: ${enrichedResponseObj.enrichedSql}")
    assert(enrichedResponseObj.enrichedSql.contains("kafka_partition"), s"UPPER(TRIM) enrichedSql missing kafka_partition: ${enrichedResponseObj.enrichedSql}")
  }

  test("executes query with nested UPPER(TRIM) transformer index") {
    val queryRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE UPPER(TRIM(Name)) = 'JUDITH GOTTLIEB'",
      "index" -> true,
      "set" -> "UNIFIED"
    ))
    val queryResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(queryRequest).send()
    assert(queryResponse.code.code == 200, s"UPPER(TRIM) indexed query failed: expected 200 but got ${queryResponse.code.code}, body: ${queryResponse.body}")
  }

  test("performance improvement with nested UPPER(TRIM) transformer index") {
    // Unindexed query (full scan)
    val unindexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE UPPER(TRIM(Name)) = 'JUDITH GOTTLIEB'",
      "index" -> false,
      "set" -> "UNIFIED"
    ))
    val unindexedStart = System.currentTimeMillis()
    val unindexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(unindexedRequest).send()
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedResponse.code.code == 200, s"UPPER(TRIM) unindexed query failed: expected 200 but got ${unindexedResponse.code.code}, body: ${unindexedResponse.body}")

    // Indexed query (using nested transformer index)
    val indexedRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE UPPER(TRIM(Name)) = 'JUDITH GOTTLIEB'",
      "index" -> true,
      "set" -> "UNIFIED"
    ))
    val indexedStart = System.currentTimeMillis()
    val indexedResponse = quickRequest.readTimeout(5.minutes).post(uri"http://hyperstream:9088/api/query").auth.basic("sbpk_12345678", "sbsk_12345678").body(indexedRequest).send()
    val indexedEnd = System.currentTimeMillis()
    assert(indexedResponse.code.code == 200, s"UPPER(TRIM) indexed perf query failed: expected 200 but got ${indexedResponse.code.code}, body: ${indexedResponse.body}")

    // Both queries should return the same results
    assert(unindexedResponse.body == indexedResponse.body, s"UPPER(TRIM) indexed and unindexed results differ.\nUnindexed: ${unindexedResponse.body.take(500)}\nIndexed: ${indexedResponse.body.take(500)}")

    val unindexedDuration = unindexedEnd - unindexedStart
    val indexedDuration = indexedEnd - indexedStart

    // Indexed query should be faster (expect 3x speedup)
    assert(indexedDuration < (unindexedDuration / 3), s"UPPER(TRIM) 3x speedup not achieved: unindexed=${unindexedDuration}ms, indexed=${indexedDuration}ms, ratio=${unindexedDuration.toDouble/indexedDuration}")
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
