/*
THIS CAN BE PREPENDED TO ANY SCALATEST SUITE, IT SHOULD NOT OUTPUT ANYTHING OR DO ANYTHING IMPERITIVE
*/

import org.scalatest.events.Event
import org.scalatest.events.TestFailed
import org.scalatest.events.TestSucceeded
import org.scalatest.Reporter

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

