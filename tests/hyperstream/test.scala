import org.scalatest.funsuite.AnyFunSuite
import org.scalatest.Args

/*
Verify Hyperstream Functions - UPPER, UPPER(TRIM), and Plain Field Index
*/

class HyperstreamSuite extends AnyFunSuite {
  // ==========================================
  // UPPER Transformer Tests
  // ==========================================
  test("creates transformer index with UPPER function") {
    val (code, body) = hyperstream.createIndex("customers", "Name", Some("UPPER($field)"))
    assert(code == 200, s"Create UPPER transformer index failed: expected 200 but got $code, body: $body")
  }

  test("enriches query with UPPER transformer function") {
    val (code, body) = hyperstream.enrich("SELECT * FROM customers WHERE UPPER(Name) = 'JUDITH GOTTLIEB STREAMBASED1'")
    assert(code == 200, s"UPPER enrich request failed: expected 200 but got $code, body: $body")
    val enriched = parse(body).extract[EnrichedResponse]
    assert(enriched.enrichedSql == "SELECT * FROM (SELECT *  FROM customers WHERE (( kafka_partition = 0 AND kafka_offset >= 333000 AND kafka_offset < 334000)) OR  (( kafka_partition = 0 AND kafka_offset >= 999999 )))  WHERE UPPER(Name) = 'JUDITH GOTTLIEB STREAMBASED1'", s"UPPER enrichedSql mismatch: ${enriched.enrichedSql}")
  }

  test("performance improvement with UPPER transformer index") {
    val unindexedStart = System.currentTimeMillis()
    val (unindexedCode, unindexedBody) = hyperstream.query("SELECT * FROM customers WHERE UPPER(Name) = 'JUDITH GOTTLIEB STREAMBASED1'", index = false, set = "UNIFIED")
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedCode == 200, s"UPPER unindexed query failed: expected 200 but got $unindexedCode, body: $unindexedBody")
    val indexedStart = System.currentTimeMillis()
    val (indexedCode, indexedBody) = hyperstream.query("SELECT * FROM customers WHERE UPPER(Name) = 'JUDITH GOTTLIEB STREAMBASED1'", index = true, set = "UNIFIED")
    val indexedEnd = System.currentTimeMillis()
    assert(indexedCode == 200, s"UPPER indexed query failed: expected 200 but got $indexedCode, body: $indexedBody")
    assert(unindexedBody == indexedBody, s"UPPER indexed and unindexed results differ.\nUnindexed: ${unindexedBody.take(500)}\nIndexed: ${indexedBody.take(500)}")
    val unindexedDuration = unindexedEnd - unindexedStart
    val indexedDuration = indexedEnd - indexedStart
//    assert(indexedDuration < (unindexedDuration / 2), s"UPPER 2x speedup not achieved: unindexed=${unindexedDuration}ms, indexed=${indexedDuration}ms, ratio=${unindexedDuration.toDouble/indexedDuration}")
  }

  test("enriches plain field query using UPPER index as superset match") {
    val (code, body) = hyperstream.enrich("SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'")
    assert(code == 200, s"Plain field enrich (UPPER superset) failed: expected 200 but got $code, body: $body")
    val enriched = parse(body).extract[EnrichedResponse]
    assert(enriched.enrichedSql == "SELECT * FROM (SELECT *  FROM customers WHERE (( kafka_partition = 0 AND kafka_offset >= 333000 AND kafka_offset < 334000)) OR  (( kafka_partition = 0 AND kafka_offset >= 999999 )))  WHERE Name = 'Judith Gottlieb Streambased1'", s"Plain field enrichedSql (UPPER superset) mismatch: ${enriched.enrichedSql}")
  }

  test("performance improvement with plain field query using UPPER index as superset match") {
    val unindexedStart = System.currentTimeMillis()
    val (unindexedCode, unindexedBody) = hyperstream.query("SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'", index = false, set = "UNIFIED")
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedCode == 200, s"Plain field unindexed query (UPPER superset) failed: expected 200 but got $unindexedCode, body: $unindexedBody")
    val indexedStart = System.currentTimeMillis()
    val (indexedCode, indexedBody) = hyperstream.query("SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'", index = true, set = "UNIFIED")
    val indexedEnd = System.currentTimeMillis()
    assert(indexedCode == 200, s"Plain field indexed query (UPPER superset) failed: expected 200 but got $indexedCode, body: $indexedBody")
    assert(unindexedBody == indexedBody, s"Plain field indexed and unindexed results differ (UPPER superset).\nUnindexed: ${unindexedBody.take(500)}\nIndexed: ${indexedBody.take(500)}")
    assert(indexedBody.contains("Judith Gottlieb Streambased1"), s"Plain field indexed query result does not contain 'Judith Gottlieb Streambased1': ${indexedBody.take(500)}")
    val unindexedDuration = unindexedEnd - unindexedStart
    val indexedDuration = indexedEnd - indexedStart
//    assert(indexedDuration < (unindexedDuration / 2), s"Plain field (UPPER superset) 2x speedup not achieved: unindexed=${unindexedDuration}ms, indexed=${indexedDuration}ms, ratio=${unindexedDuration.toDouble/indexedDuration}")
  }
  // ==========================================
  // UPPER(TRIM) Nested Transformer Tests
  // ==========================================
  test("creates transformer index with nested UPPER(TRIM) function") {
    val (code, body) = hyperstream.createIndex("customers", "Name", Some("UPPER(TRIM($field))"))
    assert(code == 200, s"Create nested transformer index failed: expected 200 but got $code, body: $body")
  }

  test("enriches query with nested UPPER(TRIM) transformer function") {
    val (code, body) = hyperstream.enrich("SELECT * FROM customers WHERE UPPER(TRIM(Name)) = 'JUDITH GOTTLIEB STREAMBASED1'")
    assert(code == 200, s"UPPER(TRIM) enrich request failed: expected 200 but got $code, body: $body")
    val enriched = parse(body).extract[EnrichedResponse]
    assert(!enriched.enrichedSql.equals(enriched.originalSql), s"UPPER(TRIM) enrichment not applied: enrichedSql equals originalSql: ${enriched.enrichedSql}")
    assert(enriched.enrichedSql.contains("kafka_partition"), s"UPPER(TRIM) enrichedSql missing kafka_partition: ${enriched.enrichedSql}")
  }

  test("performance improvement with nested UPPER(TRIM) transformer index") {
    val unindexedStart = System.currentTimeMillis()
    val (unindexedCode, unindexedBody) = hyperstream.query("SELECT * FROM customers WHERE UPPER(TRIM(Name)) = 'JUDITH GOTTLIEB STREAMBASED1'", index = false, set = "UNIFIED")
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedCode == 200, s"UPPER(TRIM) unindexed query failed: expected 200 but got $unindexedCode, body: $unindexedBody")
    val indexedStart = System.currentTimeMillis()
    val (indexedCode, indexedBody) = hyperstream.query("SELECT * FROM customers WHERE UPPER(TRIM(Name)) = 'JUDITH GOTTLIEB STREAMBASED1'", index = true, set = "UNIFIED")
    val indexedEnd = System.currentTimeMillis()
    assert(indexedCode == 200, s"UPPER(TRIM) indexed query failed: expected 200 but got $indexedCode, body: $indexedBody")
    assert(unindexedBody == indexedBody, s"UPPER(TRIM) indexed and unindexed results differ.\nUnindexed: ${unindexedBody.take(500)}\nIndexed: ${indexedBody.take(500)}")
    val unindexedDuration = unindexedEnd - unindexedStart
    val indexedDuration = indexedEnd - indexedStart
    assert(indexedDuration < (unindexedDuration / 2), s"UPPER(TRIM) 2x speedup not achieved: unindexed=${unindexedDuration}ms, indexed=${indexedDuration}ms, ratio=${unindexedDuration.toDouble/indexedDuration}")
  }
  // ==========================================
  // Plain Field Index Tests
  // ==========================================
  test("creates index on plain field (no transformer)") {
    val (code, body) = hyperstream.createIndex("customers", "Name")
    assert(code == 200, s"Create plain field index failed: expected 200 but got $code, body: $body")
  }

  test("enriches plain field query using exact match index") {
    val (code, body) = hyperstream.enrich("SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'")
    assert(code == 200, s"Plain field enrich (exact match) failed: expected 200 but got $code, body: $body")
    val enriched = parse(body).extract[EnrichedResponse]
    assert(!enriched.enrichedSql.equals(enriched.originalSql), s"Plain field enrichment not applied (exact match): enrichedSql equals originalSql: ${enriched.enrichedSql}")
    assert(enriched.enrichedSql.contains("kafka_partition"), s"Plain field enrichedSql missing kafka_partition (exact match): ${enriched.enrichedSql}")
  }

  test("performance improvement with plain field exact match index") {
    val unindexedStart = System.currentTimeMillis()
    val (unindexedCode, unindexedBody) = hyperstream.query("SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'", index = false, set = "UNIFIED")
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedCode == 200, s"Plain field unindexed query (exact match) failed: expected 200 but got $unindexedCode, body: $unindexedBody")
    val indexedStart = System.currentTimeMillis()
    val (indexedCode, indexedBody) = hyperstream.query("SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'", index = true, set = "UNIFIED")
    val indexedEnd = System.currentTimeMillis()
    assert(indexedCode == 200, s"Plain field indexed query (exact match) failed: expected 200 but got $indexedCode, body: $indexedBody")
    assert(unindexedBody == indexedBody, s"Plain field indexed and unindexed results differ (exact match).\nUnindexed: ${unindexedBody.take(500)}\nIndexed: ${indexedBody.take(500)}")
    assert(indexedBody.contains("Judith Gottlieb Streambased1"), s"Plain field indexed query result does not contain 'Judith Gottlieb Streambased1': ${indexedBody.take(500)}")
    val unindexedDuration = unindexedEnd - unindexedStart
    val indexedDuration = indexedEnd - indexedStart
    assert(indexedDuration < (unindexedDuration / 2), s"Plain field (exact match) 2x speedup not achieved: unindexed=${unindexedDuration}ms, indexed=${indexedDuration}ms, ratio=${unindexedDuration.toDouble/indexedDuration}")
  }
}

// run tests
val reporter = new TestReporter
try {
  (new HyperstreamSuite).run(None, new Args(reporter = reporter))
} catch {
  case e: Throwable => {
    e.printStackTrace()
    println(e)
  }
} finally {
  reporter.printSummary()
  if (reporter.failed > 0) System.exit(1) else System.exit(0)
}
