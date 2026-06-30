/*
Hyperstream HTTP client - prepend to any test that calls the Hyperstream API.
Requires net.liftweb:lift-json on the classpath.
*/
import net.liftweb.json._
import java.util.Base64

implicit val formats: DefaultFormats.type = net.liftweb.json.DefaultFormats

case class EnrichedResponse(originalSql: String, enrichedSql: String)

class HyperstreamClient(baseUrl: String, apiKey: String, secretKey: String, timeoutMs: Int = 1200000) {
  private val authHeader = "Basic " + Base64.getEncoder.encodeToString(s"$apiKey:$secretKey".getBytes)
  private def request(method: String, path: String, body: Option[String] = None): (Int, String) = {
    val url = new java.net.URL(s"$baseUrl$path")
    val conn = url.openConnection().asInstanceOf[java.net.HttpURLConnection]
    conn.setConnectTimeout(timeoutMs)
    conn.setReadTimeout(timeoutMs)
    conn.setRequestMethod(method)
    conn.setRequestProperty("Content-Type", "application/json")
    conn.setRequestProperty("Authorization", authHeader)
    body.foreach { b =>
      conn.setDoOutput(true)
      val os = conn.getOutputStream
      os.write(b.getBytes("UTF-8"))
      os.flush()
    }
    val code = conn.getResponseCode
    val stream = if (code < 400) conn.getInputStream else conn.getErrorStream
    val responseBody = if (stream != null) scala.io.Source.fromInputStream(stream).mkString else ""
    (code, responseBody)
  }
  def createIndex(topic: String, field: String, transformerFunction: Option[String] = None): (Int, String) = {
    val base = Map("topic" -> topic, "field" -> field)
    val params = transformerFunction.map(f => base + ("transformerFunction" -> f)).getOrElse(base)
    request("PUT", "/api/index", Some(Serialization.write(params)))
  }
  def enrich(sql: String): (Int, String) = {
    request("POST", "/api/enrich", Some(Serialization.write(Map("sql" -> sql))))
  }
  def query(sql: String, index: Boolean, set: String): (Int, String) = {
    val json = s"""{"sql":${Serialization.write(sql)},"index":$index,"set":${Serialization.write(set)}}"""
    request("POST", "/api/query", Some(json))
  }
}

val hyperstream = new HyperstreamClient("http://hyperstream:9088", "sbpk_12345678", "sbsk_12345678")
