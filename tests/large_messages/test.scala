import org.scalatest.funsuite.AnyFunSuite
import org.scalatest.Args

/*
Verify Core Functions
*/
class LargeMessagesSuite extends AnyFunSuite {
    test("Can fetch messages") {
        val rows = spark.sql("SELECT * FROM hotset.customers LIMIT 10")
            .collect
            .toList
        assert(rows.size == 10)
    }
}

// run tests
val reporter = new TestReporter
try {
   (new LargeMessagesSuite).run(None, new Args(reporter = reporter))
} catch {
    case e: Throwable => {
        println(e)
    }
} finally {
    reporter.printSummary()
    if (reporter.failed > 0) System.exit(1) else System.exit(0)
}
