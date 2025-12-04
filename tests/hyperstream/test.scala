import org.scalatest.FunSuite
import org.scalatest.Args

/*
Verify Hyperstream Functions
*/
import sttp.client4.quick._
import net.liftweb.json._
implicit val formats = net.liftweb.json.DefaultFormats


class HyperstreamSuite extends FunSuite {
  test("creates index and uses it") {

    // let's create an index
    val indexCreateRequest = Serialization.write(Map(
      "topic" -> "customers",
      "field" -> "Name"
    ))
    val indexCreateResponse = quickRequest.put(uri"http://hyperstream:9088/api/index").body(indexCreateRequest).send()
    assert(indexCreateResponse.code.code == 200)

    // now check enrichment
    val enrichRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb'"
    ))
    val enrichResponse = quickRequest.post(uri"http://hyperstream:9088/api/enrich").body(enrichRequest).send()
    assert(enrichResponse.code.code == 200)

    case class EnrichedResponse(originalSql:String, enrichedSql:String)

    val parsed = parse(enrichResponse.body)
    val enrichedResponseObj = parsed.extract[EnrichedResponse]
    assert(enrichedResponseObj.originalSql == "SELECT * FROM customers WHERE Name = 'Judith Gottlieb'")
    assert(enrichedResponseObj.enrichedSql == "SELECT * FROM (SELECT *  FROM customers WHERE (( kafka_partition = 0 AND kafka_offset >= 334000 AND kafka_offset < 335000)) OR  (( kafka_partition = 0 AND kafka_offset >= 999999 )))  WHERE Name = 'Judith Gottlieb'")

    // time execution
    val unindexedQueryRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb'",
      "index" -> false,
      "set" -> "UNIFIED"
    ))
    val unindexedStartTime = System.currentTimeMillis()
    val unindexedResponse = quickRequest.post(uri"http://hyperstream:9088/api/query").body(unindexedQueryRequest).send()
    val unindexedEndTime = System.currentTimeMillis()
    assert(unindexedResponse.code.code == 200)

    val indexedQueryRequest = Serialization.write(Map(
      "sql" -> "SELECT * FROM customers WHERE Name = 'Judith Gottlieb'",
      "index" -> true,
      "set" -> "UNIFIED"
    ))
    val indexedStartTime = System.currentTimeMillis()
    val indexedResponse = quickRequest.post(uri"http://hyperstream:9088/api/query").body(indexedQueryRequest).send()
    val indexedEndTime = System.currentTimeMillis()
    assert(indexedResponse.code.code == 200)

    // should produce the same result and that it contains the searched value
    assert(unindexedResponse.body == indexedResponse.body)
    assert(indexedResponse.body.contains("Judith Gottlieb"))

    val unindexDuration  = unindexedEndTime - unindexedStartTime
    val indexDuration  = indexedEndTime - indexedStartTime

    // assert 3x speedup
    assert(indexDuration < (unindexDuration/3))
  }
}

// run tests
try {
  (new HyperstreamSuite).run(None, new Args(reporter = new TestReporter))
} catch {
  case e: Throwable => {
    println(e)
    System.exit(1)
  }
} finally {
  System.exit(0)
}
