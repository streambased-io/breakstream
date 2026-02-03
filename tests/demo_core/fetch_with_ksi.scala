println(s"${GREEN}\n\nLet's fetch some messages!${RESET}")

ksiConsumer.subscribe(ArrayBuffer("transactions").asJava)
var ksiRecords = ksiConsumer.poll(Duration.ofSeconds(2))
val startTime = System.currentTimeMillis()
while (ksiRecords.count() == 0 && (System.currentTimeMillis() - startTime) < 60000) {
  ksiRecords = ksiConsumer.poll(Duration.ofSeconds(2))
}
val ksiIter = ksiRecords.records("transactions").iterator()
var ksiRecordsDisplayed = 0
while (ksiIter.hasNext && ksiRecordsDisplayed < 10) {
  val record = ksiIter.next()
  println(s"${GREEN}offset = ${RED}${record.offset()}${GREEN}, key = ${record.key()}, value = ${record.value()}${RESET}")
  ksiRecordsDisplayed += 1
}

println("section complete")
