import org.scalatest.funsuite.AnyFunSuite
import org.scalatest.Args

/*
Verify Hyperstream SUBSTRING Transformer Functions
*/

class SubstringSuite extends AnyFunSuite {
  // ==========================================
  // SUBSTRING Transformer Tests
  // ==========================================
  test("creates transformer index with SUBSTRING function") {
    val (code, body) = hyperstream.createIndex("customers", "Name", Some("SUBSTRING($field, 1, 27)"))
    println(s"[DEBUG] Create index response: code=$code body=$body")
    assert(code == 200, s"Create SUBSTRING transformer index failed: expected 200 but got $code, body: $body")
  }

  test("enriches query with SUBSTRING transformer function") {
    val (code, body) = hyperstream.enrich("SELECT * FROM customers WHERE SUBSTRING(Name, 1, 27) = 'Judith Gottlieb Streambased'")
    assert(code == 200, s"SUBSTRING enrich request failed: expected 200 but got $code, body: $body")
    val enriched = parse(body).extract[EnrichedResponse]
    assert(enriched.enrichedSql == "SELECT * FROM (SELECT *  FROM customers WHERE (( kafka_partition = 0 AND kafka_offset >= 333000 AND kafka_offset < 334000) OR ( kafka_partition = 0 AND kafka_offset >= 663000 AND kafka_offset < 664000)) OR  (( kafka_partition = 0 AND kafka_offset >= 999999 )))  WHERE SUBSTRING(Name, 1, 27) = 'Judith Gottlieb Streambased'", s"SUBSTRING enrichedSql mismatch: ${enriched.enrichedSql}")
  }

  test("performance improvement with SUBSTRING transformer index") {
    val unindexedStart = System.currentTimeMillis()
    val (unindexedCode, unindexedBody) = hyperstream.query("SELECT * FROM customers WHERE SUBSTRING(Name, 1, 27) = 'Judith Gottlieb Streambased'", index = false, set = "UNIFIED")
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedCode == 200, s"SUBSTRING unindexed query failed: expected 200 but got $unindexedCode, body: $unindexedBody")
    val indexedStart = System.currentTimeMillis()
    val (indexedCode, indexedBody) = hyperstream.query("SELECT * FROM customers WHERE SUBSTRING(Name, 1, 27) = 'Judith Gottlieb Streambased'", index = true, set = "UNIFIED")
    val indexedEnd = System.currentTimeMillis()
    assert(indexedCode == 200, s"SUBSTRING indexed query failed: expected 200 but got $indexedCode, body: $indexedBody")
    assert(unindexedBody == indexedBody, s"SUBSTRING indexed and unindexed results differ.\nUnindexed: ${unindexedBody.take(500)}\nIndexed: ${indexedBody.take(500)}")
    val unindexedDuration = unindexedEnd - unindexedStart
    val indexedDuration = indexedEnd - indexedStart
    assert(indexedDuration < (unindexedDuration / 2), s"SUBSTRING 2x speedup not achieved: unindexed=${unindexedDuration}ms, indexed=${indexedDuration}ms, ratio=${unindexedDuration.toDouble/indexedDuration}")
  }

  test("enriches plain field query using SUBSTRING index as superset match") {
    val (code, body) = hyperstream.enrich("SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'")
    assert(code == 200, s"Plain field enrich (SUBSTRING superset) failed: expected 200 but got $code, body: $body")
    val enriched = parse(body).extract[EnrichedResponse]
    assert(enriched.enrichedSql == "SELECT * FROM (SELECT *  FROM customers WHERE (( kafka_partition = 0 AND kafka_offset >= 333000 AND kafka_offset < 334000) OR ( kafka_partition = 0 AND kafka_offset >= 663000 AND kafka_offset < 664000)) OR  (( kafka_partition = 0 AND kafka_offset >= 999999 )))  WHERE Name = 'Judith Gottlieb Streambased1'", s"Plain field enrichedSql (SUBSTRING superset) mismatch: ${enriched.enrichedSql}")
  }

  test("performance improvement with plain field query using SUBSTRING index as superset match") {
    val unindexedStart = System.currentTimeMillis()
    val (unindexedCode, unindexedBody) = hyperstream.query("SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'", index = false, set = "UNIFIED")
    val unindexedEnd = System.currentTimeMillis()
    assert(unindexedCode == 200, s"Plain field unindexed query failed: expected 200 but got $unindexedCode, body: $unindexedBody")
    val indexedStart = System.currentTimeMillis()
    val (indexedCode, indexedBody) = hyperstream.query("SELECT * FROM customers WHERE Name = 'Judith Gottlieb Streambased1'", index = true, set = "UNIFIED")
    val indexedEnd = System.currentTimeMillis()
    assert(indexedCode == 200, s"Plain field indexed query (SUBSTRING superset) failed: expected 200 but got $indexedCode, body: $indexedBody")
    assert(unindexedBody == indexedBody, s"Plain field indexed and unindexed results differ (SUBSTRING superset).\nUnindexed: ${unindexedBody.take(500)}\nIndexed: ${indexedBody.take(500)}")
    assert(indexedBody.contains("Judith Gottlieb Streambased1"), s"Plain field indexed query result does not contain 'Judith Gottlieb Streambased1': ${indexedBody.take(500)}")
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
