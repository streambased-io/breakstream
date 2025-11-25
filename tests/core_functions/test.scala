import org.scalatest.FunSuite
import org.scalatest.Args
import org.scalatest.Reporter
import org.scalatest.events.Event
import org.scalatest.events.TestFailed
import org.scalatest.events.TestSucceeded

/*
Verify Core Functions
*/
var exitCode = 0

// TODO: either get rid of this or move it somewhere common
class TestReporter extends Reporter {
  def apply(event: Event): Unit = {
    event match {
          case event: TestFailed => {
            println("TEST: " + event.testName + " in SUITE: " + event.suiteName + " FAILED")
            println(event.message)
            System.exit(1)
          }
          case event: TestSucceeded => {
            println("TEST: " + event.testName + " in SUITE: " + event.suiteName + " SUCCEEDED")
          }
          case _ =>
        }
  }
}

class CoreFunctionsSuite extends FunSuite { 
    test("All 3 databases exist") {
        val databases = spark.sql("SHOW DATABASES")
            .select("namespace")
            .collect
            .map(row => row.getString(0))
            .sorted
            .toList
        assert(databases == List("coldset", "hotset", "merged"))
    }

    test("Hotset tables") {
        val hotsetTables = spark.sql("SHOW TABLES IN hotset")
            .select("tablename")
            .collect
            .map(row => row.getString(0))
            .sorted
            .toList
        assert(hotsetTables == List("customers", "transactions"))
    }

    test("Coldset tables") {
        val coldsetTables = spark.sql("SHOW TABLES IN coldset")
            .select("tablename")
            .collect
            .map(row => row.getString(0))
            .sorted
            .toList
        assert(coldsetTables == List("branches", "customers", "transactions"))
    }

    test("Merged tables") {
        val mergedTables = spark.sql("SHOW TABLES IN merged")
            .select("tablename")
            .collect
            .map(row => row.getString(0))
            .sorted
            .toList
        assert(mergedTables == List("branches", "customers", "transactions"))
    }

    test("Row counts") {
        val coldsetCount = spark.sql("SELECT COUNT(*) FROM coldset.transactions")
            .head
            .getLong(0)

        val hotsetCount = spark.sql("SELECT COUNT(*) FROM hotset.transactions")
            .head
            .getLong(0)

        val mergedCount = spark.sql("SELECT COUNT(*) FROM merged.transactions")
            .head
            .getLong(0)

        assert(coldsetCount == 500000)
        assert(hotsetCount > 0)
        assert(mergedCount >= coldsetCount + hotsetCount)
    }

}

// run tests
try {
   (new CoreFunctionsSuite).run(None, new Args(reporter = new TestReporter))
} catch {
    case e: Throwable => {
        println(e)
        System.exit(1)
    }
} finally {
    val isComplete = true
    System.exit(exitCode)
}
