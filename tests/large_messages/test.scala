import org.scalatest.FunSuite
import org.scalatest.Args

/*
Verify Core Functions
*/
class LargeMessagesSuite extends FunSuite {
    test("Can fetch messages") {
        val rows = spark.sql("SELECT * FROM hotset.customers LIMIT 10")
            .collect
            .toList
        assert(rows.size == 10)
    }
}

// run tests
try {
   (new LargeMessagesSuite).run(None, new Args(reporter = new TestReporter))
} catch {
    case e: Throwable => {
        println(e)
        System.exit(1)
    }
} finally {
    System.exit(0)
}
