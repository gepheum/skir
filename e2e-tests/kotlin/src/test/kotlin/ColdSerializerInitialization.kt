import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

object ColdSerializerInitialization {
    @JvmStatic
    fun main(args: Array<String>) {
        when (args.singleOrNull()) {
            "serializer" -> serializerAccess()
            "descriptor" -> descriptorAccess()
            "enum" -> enumAccess()
            "string" -> stringAccess()
            "concurrent" -> concurrentAccess()
            "field" -> fieldAccess()
            "record" -> recordAccess()
            "value" -> valueAccess()
            "valueConcurrent" -> valueConcurrentAccess()
            else -> error("Expected one cold initialization scenario")
        }
    }

    private fun serializerAccess() {
        check(
            skirout.structs.RecA.serializer.toJsonCode(
                skirout.structs.RecA.partial(),
            ).isNotEmpty(),
        )
    }

    private fun descriptorAccess() {
        check(skirout.structs.RecB.typeDescriptor.qualifiedName == "RecB")
    }

    private fun enumAccess() {
        check(skirout.enums.Status.typeDescriptor.qualifiedName == "Status")
    }

    private fun stringAccess() {
        check(skirout.structs.RecB.partial().toString().isNotEmpty())
    }

    private fun fieldAccess() {
        val value = skirout.recursive_value.Field.partial(name = "leaf")
        val serializer = skirout.recursive_value.Field.serializer
        check(serializer.fromBytes(serializer.toBytes(value)) == value)
    }

    private fun recordAccess() {
        val value =
            skirout.recursive_value.Record.partial(
                fields = listOf(skirout.recursive_value.Field.partial(name = "leaf")),
            )
        val serializer = skirout.recursive_value.Record.serializer
        check(serializer.fromBytes(serializer.toBytes(value)) == value)
    }

    private fun valueAccess() {
        val value =
            skirout.recursive_value.Value.createRecord(
                fields = listOf(skirout.recursive_value.Field.partial(name = "leaf")),
            )
        val serializer = skirout.recursive_value.Value.serializer
        check(serializer.fromBytes(serializer.toBytes(value)) == value)
    }

    private fun concurrentAccess() {
        runConcurrently(
            listOf(
                ::serializerAccess,
                ::descriptorAccess,
                ::enumAccess,
                ::stringAccess,
            ),
        )
    }

    private fun valueConcurrentAccess() {
        runConcurrently(listOf(::fieldAccess, ::valueAccess))
    }

    private fun runConcurrently(operations: List<() -> Unit>) {
        val start = CountDownLatch(1)
        val executor =
            Executors.newFixedThreadPool(8) { runnable ->
                Thread(runnable, "cold serializer access").apply {
                    isDaemon = true
                }
            }
        try {
            val futures =
                (0 until 32).map { index ->
                    executor.submit {
                        start.await()
                        operations[index % operations.size]()
                    }
                }
            start.countDown()
            futures.forEach { it.get(10, TimeUnit.SECONDS) }
        } finally {
            executor.shutdownNow()
        }
    }
}
