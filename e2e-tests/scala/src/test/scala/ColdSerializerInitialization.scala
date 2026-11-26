import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import scala.jdk.CollectionConverters.*

object ColdSerializerInitialization {
  def main(args: Array[String]): Unit =
    args.headOption match {
      case Some("serializer")      => serializerAccess()
      case Some("descriptor")      => descriptorAccess()
      case Some("enum")            => enumAccess()
      case Some("string")          => stringAccess()
      case Some("concurrent")      => concurrentAccess()
      case Some("field")           => fieldAccess()
      case Some("record")          => recordAccess()
      case Some("value")           => valueAccess()
      case Some("valueConcurrent") => valueConcurrentAccess()
      case _ => throw new IllegalStateException("Expected one cold initialization scenario")
    }

  private def serializerAccess(): Unit =
    assert(
      skirout.structs.RecA.serializer
        .toJsonCode(skirout.structs.RecA.partial())
        .nonEmpty,
    )

  private def descriptorAccess(): Unit =
    assert(skirout.structs.RecB.typeDescriptor.getQualifiedName == "RecB")

  private def enumAccess(): Unit =
    assert(skirout.enums.Status.typeDescriptor.getQualifiedName == "Status")

  private def stringAccess(): Unit =
    assert(skirout.structs.RecB.partial().toString.nonEmpty)

  private def fieldAccess(): Unit = {
    val value = skirout.recursive_value.Field.partial(name = "leaf")
    val serializer = skirout.recursive_value.Field.serializer
    assert(serializer.fromBytes(serializer.toBytes(value)) == value)
  }

  private def recordAccess(): Unit = {
    val value = skirout.recursive_value.Record.partial(
      fields = Seq(skirout.recursive_value.Field.partial(name = "leaf")).asJava,
    )
    val serializer = skirout.recursive_value.Record.serializer
    assert(serializer.fromBytes(serializer.toBytes(value)) == value)
  }

  private def valueAccess(): Unit = {
    val value = skirout.recursive_value.Value.createRecord(
      fields = Seq(skirout.recursive_value.Field.partial(name = "leaf")).asJava,
    )
    val serializer = skirout.recursive_value.Value.serializer
    assert(serializer.fromBytes(serializer.toBytes(value)) == value)
  }

  private def concurrentAccess(): Unit =
    runConcurrently(
      Seq(
        () => serializerAccess(),
        () => descriptorAccess(),
        () => enumAccess(),
        () => stringAccess(),
      ),
    )

  private def valueConcurrentAccess(): Unit =
    runConcurrently(Seq(() => fieldAccess(), () => valueAccess()))

  private def runConcurrently(operations: Seq[() => Unit]): Unit = {
    val start = new CountDownLatch(1)
    val executor = Executors.newFixedThreadPool(
      8,
      (runnable: Runnable) => {
        val t = new Thread(runnable, "cold serializer access")
        t.setDaemon(true)
        t
      },
    )
    try {
      val futures = (0 until 32).map { index =>
        executor.submit(new Runnable {
          override def run(): Unit = {
            start.await()
            operations(index % operations.size)()
          }
        })
      }
      start.countDown()
      futures.foreach(_.get(10, TimeUnit.SECONDS))
    } finally {
      executor.shutdownNow()
    }
  }
}
