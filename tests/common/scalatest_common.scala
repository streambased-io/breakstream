/*
THIS CAN BE PREPENDED TO ANY SCALATEST SUITE, IT SHOULD NOT OUTPUT ANYTHING OR DO ANYTHING IMPERITIVE
*/

import org.scalatest.events.Event
import org.scalatest.events.TestFailed
import org.scalatest.events.TestSucceeded
import org.scalatest.Reporter

class TestReporter extends Reporter {
  var passed = 0
  var failed = 0
  val failures = scala.collection.mutable.ArrayBuffer[(String, String)]()
  def apply(event: Event): Unit = {
    event match {
      case event: TestFailed => {
        failed += 1
        failures += ((event.testName, event.message))
        println("TEST: " + event.testName + " in SUITE: " + event.suiteName + " FAILED")
        println(event.message)
        event.throwable match {
          case Some(t) =>
            println("Exception: " + t.getClass.getName + ": " + t.getMessage)
            t.printStackTrace()
            if (t.getCause != null) {
              println("Caused by: " + t.getCause.getClass.getName + ": " + t.getCause.getMessage)
              t.getCause.printStackTrace()
            }
          case None =>
        }
      }
      case event: TestSucceeded => {
        passed += 1
        println("TEST: " + event.testName + " in SUITE: " + event.suiteName + " SUCCEEDED")
      }
      case _ =>
    }
  }
  def printSummary(): Unit = {
    val total = passed + failed
    println("")
    println("=" * 60)
    println(s"TEST SUMMARY: $total tests run, $passed passed, $failed failed")
    if (failures.nonEmpty) {
      println("-" * 60)
      failures.foreach { case (name, msg) =>
        println(s"  FAILED: $name")
        println(s"          $msg")
      }
    }
    println("=" * 60)
    println("")
  }
}

