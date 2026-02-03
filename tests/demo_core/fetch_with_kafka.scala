println(s"${GREEN}\n\nLet's fetch some messages!${RESET}")

kafkaConsumer.subscribe(ArrayBuffer("transactions").asJava)
var kafkaRecords = kafkaConsumer.poll(Duration.ofSeconds(2))
val startTime = System.currentTimeMillis()
while (kafkaRecords.count() == 0 && (System.currentTimeMillis() - startTime) < 60000) {
  kafkaRecords = kafkaConsumer.poll(Duration.ofSeconds(2))
}
val iter = kafkaRecords.records("transactions").iterator()
var recordsDisplayed = 0
while (iter.hasNext && recordsDisplayed < 10) {
  val record = iter.next()
  println(s"${GREEN}offset = ${RED}${record.offset()}${GREEN}, key = ${record.key()}, value = ${record.value()}${RESET}")
  recordsDisplayed += 1
}

println("section complete")
