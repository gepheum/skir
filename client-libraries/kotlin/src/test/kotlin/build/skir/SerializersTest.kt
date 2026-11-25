package build.skir

import build.skir.internal.toStringImpl
import build.skir.reflection.ArrayDescriptor
import build.skir.reflection.EnumDescriptor
import build.skir.reflection.OptionalDescriptor
import build.skir.reflection.PrimitiveDescriptor
import build.skir.reflection.RecordDescriptor
import build.skir.reflection.StructDescriptor
import build.skir.reflection.TypeDescriptor
import build.skir.reflection.parseTypeDescriptorImpl
import com.google.common.truth.Truth.assertThat
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonPrimitive
import okio.ByteString
import okio.ByteString.Companion.decodeHex
import okio.ByteString.Companion.encodeUtf8
import org.junit.jupiter.api.Test
import java.time.Instant

class SerializersTest {
    @Test
    fun `test bool serializer - basic functionality`() {
        // Test true value - should be 1 in dense, true in readable
        assertThat(
            (build.skir.Serializers.bool.toJson(false, JsonFlavor.READABLE).jsonPrimitive.content),
        ).isEqualTo("false")
        assertThat((build.skir.Serializers.bool.toJson(false).jsonPrimitive.content)).isEqualTo("0")
        assertThat(
            (build.skir.Serializers.bool.toJson(true, JsonFlavor.READABLE).jsonPrimitive.content),
        ).isEqualTo("true")
        assertThat((build.skir.Serializers.bool.toJson(true).jsonPrimitive.content)).isEqualTo("1")

        // Test round-trip
        assertThat(build.skir.Serializers.bool.fromJson(JsonPrimitive(true))).isEqualTo(true)
        assertThat(build.skir.Serializers.bool.fromJsonCode("true")).isEqualTo(true)
        assertThat(build.skir.Serializers.bool.fromJsonCode("1")).isEqualTo(true)
        assertThat(build.skir.Serializers.bool.fromJsonCode("100")).isEqualTo(true)
        assertThat(build.skir.Serializers.bool.fromJsonCode("3.14")).isEqualTo(true)
        assertThat(build.skir.Serializers.bool.fromJsonCode("\"1\"")).isEqualTo(true)
        assertThat(build.skir.Serializers.bool.fromJsonCode("false")).isEqualTo(false)
        assertThat(build.skir.Serializers.bool.fromJsonCode("0")).isEqualTo(false)
        assertThat(build.skir.Serializers.bool.fromJsonCode("\"0\"")).isEqualTo(false)
    }

    @Test
    fun `test bool serializer - binary serialization`() {
        // From TypeScript tests: true -> "01", false -> "00"
        val trueBytes = build.skir.Serializers.bool.toBytes(true)
        assertThat(trueBytes.hex()).isEqualTo("736b697201")

        val falseBytes = build.skir.Serializers.bool.toBytes(false)
        assertThat(falseBytes.hex()).isEqualTo("736b697200")

        // Test round trip
        val restoredTrue = build.skir.Serializers.bool.fromBytes(trueBytes.toByteArray())
        assertThat(restoredTrue).isEqualTo(true)

        val restoredFalse = build.skir.Serializers.bool.fromBytes(falseBytes)
        assertThat(restoredFalse).isEqualTo(false)

        assertThat(build.skir.Serializers.bool.fromBytes(build.skir.Serializers.int32.toBytes(100))).isEqualTo(true)
        assertThat(build.skir.Serializers.bool.fromBytes(build.skir.Serializers.float32.toBytes(3.14F))).isEqualTo(true)
        assertThat(
            build.skir.Serializers.bool.fromBytes(build.skir.Serializers.hash64.toBytes(10000000000000000UL)),
        ).isEqualTo(true)
        assertThat(build.skir.Serializers.bool.fromBytes(build.skir.Serializers.hash64.toBytes(0UL))).isEqualTo(false)
        assertThat(build.skir.Serializers.bool.fromBytes(build.skir.Serializers.int64.toBytes(-1))).isEqualTo(true)
    }

    @Test
    fun `test int32 serializer`() {
        val values = listOf(0, 1, -1, 42, -42, Int.MAX_VALUE, Int.MIN_VALUE)

        for (value in values) {
            // JSON serialization
            val jsonCode = build.skir.Serializers.int32.toJsonCode(value)
            val restored = build.skir.Serializers.int32.fromJsonCode(jsonCode)
            assertThat(restored).isEqualTo(value)

            // Binary serialization
            val bytes = build.skir.Serializers.int32.toBytes(value)
            val restoredFromBytes = build.skir.Serializers.int32.fromBytes(bytes.toByteArray())
            assertThat(restoredFromBytes).isEqualTo(value)

            // JsonFlavor shouldn't affect primitive numbers
            assertThat(
                build.skir.Serializers.int32.toJsonCode(value),
            ).isEqualTo(
                build.skir.Serializers.int32.toJsonCode(value, JsonFlavor.READABLE),
            )
        }
    }

    @Test
    fun `test int64 serializer`() {
        val values = listOf(0L, 1L, -1L, 42L, -42L, Long.MAX_VALUE, Long.MIN_VALUE)

        for (value in values) {
            val jsonCode = build.skir.Serializers.int64.toJsonCode(value)
            val restored = build.skir.Serializers.int64.fromJsonCode(jsonCode)
            assertThat(restored).isEqualTo(value)

            val bytes = build.skir.Serializers.int64.toBytes(value)
            val restoredFromBytes = build.skir.Serializers.int64.fromBytes(bytes.toByteArray())
            assertThat(restoredFromBytes).isEqualTo(value)
        }
    }

    @Test
    fun `test hash64 serializer`() {
        val values = listOf(0UL, 1UL, 42UL, ULong.MAX_VALUE)

        for (value in values) {
            val jsonCode = build.skir.Serializers.hash64.toJsonCode(value)
            val restored = build.skir.Serializers.hash64.fromJsonCode(jsonCode)
            assertThat(restored).isEqualTo(value)

            val bytes = build.skir.Serializers.hash64.toBytes(value)
            val restoredFromBytes = build.skir.Serializers.hash64.fromBytes(bytes.toByteArray())
            assertThat(restoredFromBytes).isEqualTo(value)
        }
    }

    @Test
    fun `test float32 serializer`() {
        val values =
            listOf(
                0.0f,
                1.0f,
                -1.0f,
                3.14f,
                Float.MAX_VALUE,
                Float.MIN_VALUE,
                Float.NaN,
                Float.POSITIVE_INFINITY,
                Float.NEGATIVE_INFINITY,
            )

        for (value in values) {
            val jsonCode = build.skir.Serializers.float32.toJsonCode(value)
            val restored = build.skir.Serializers.float32.fromJsonCode(jsonCode)

            if (value.isNaN()) {
                assertThat(restored.isNaN()).isTrue()
            } else {
                assertThat(restored).isEqualTo(value)
            }

            val bytes = build.skir.Serializers.float32.toBytes(value)
            val restoredFromBytes = build.skir.Serializers.float32.fromBytes(bytes.toByteArray())

            if (value.isNaN()) {
                assertThat(restoredFromBytes.isNaN()).isTrue()
            } else {
                assertThat(restoredFromBytes).isEqualTo(value)
            }
        }
    }

    @Test
    fun `test float64 serializer`() {
        val values =
            listOf(
                0.0,
                1.0,
                -1.0,
                3.14159265359,
                Double.MAX_VALUE,
                Double.MIN_VALUE,
                Double.NaN,
                Double.POSITIVE_INFINITY,
                Double.NEGATIVE_INFINITY,
            )

        for (value in values) {
            val jsonCode = build.skir.Serializers.float64.toJsonCode(value)
            val restored = build.skir.Serializers.float64.fromJsonCode(jsonCode)

            if (value.isNaN()) {
                assertThat(restored.isNaN()).isTrue()
            } else {
                assertThat(restored).isEqualTo(value)
            }

            val bytes = build.skir.Serializers.float64.toBytes(value)
            val restoredFromBytes = build.skir.Serializers.float64.fromBytes(bytes.toByteArray())

            if (value.isNaN()) {
                assertThat(restoredFromBytes.isNaN()).isTrue()
            } else {
                assertThat(restoredFromBytes).isEqualTo(value)
            }
        }
    }

    @Test
    fun `test string serializer`() {
        val values =
            listOf(
                "",
                "hello",
                "world",
                "Hello, 世界!",
                "🚀",
                "\n\t\r",
                "A very long string that exceeds normal buffer sizes and should " +
                    "test the streaming capabilities of the serializer properly",
            )

        for (value in values) {
            val jsonCode = build.skir.Serializers.string.toJsonCode(value)
            val restored = build.skir.Serializers.string.fromJsonCode(jsonCode)
            assertThat(restored).isEqualTo(value)

            val bytes = build.skir.Serializers.string.toBytes(value)
            val restoredFromBytes = build.skir.Serializers.string.fromBytes(bytes.toByteArray())
            assertThat(restoredFromBytes).isEqualTo(value)

            // JsonFlavor shouldn't affect plain strings
            assertThat(
                build.skir.Serializers.string.toJsonCode(value, JsonFlavor.READABLE),
            ).isEqualTo(
                build.skir.Serializers.string.toJsonCode(value),
            )
        }

        assertThat(build.skir.Serializers.string.fromJsonCode("0")).isEqualTo("")
    }

    @Test
    fun `test string serializer invalid UTF-8 sanitization`() {
        // 0xFF is not valid UTF-8. Decoding should not throw and should replace it.
        val invalidBytes = "736b6972f302ff7a".decodeHex()
        assertThat(build.skir.Serializers.string.fromBytes(invalidBytes.toByteArray())).isEqualTo("�z")

        // Lone surrogates are sanitized during UTF-8 encoding.
        val restored =
            build.skir.Serializers.string.fromBytes(
                build.skir.Serializers.string.toBytes("\uD800z").toByteArray(),
            )
        assertThat(restored).isEqualTo("?z")
    }

    @Test
    fun `test bytes serializer - dense flavor`() {
        val values =
            listOf(
                ByteString.EMPTY,
                "hello".encodeUtf8(),
                "world".encodeUtf8(),
                "Hello, 世界!".encodeUtf8(),
            )

        for (value in values) {
            // Test DENSE flavor (should use base64)
            val denseJson = build.skir.Serializers.bytes.toJsonCode(value)
            val restoredFromDense = build.skir.Serializers.bytes.fromJsonCode(denseJson)
            assertThat(restoredFromDense).isEqualTo(value)

            // Dense should produce a base64 string (not hex)
            assertThat(denseJson).startsWith("\"")
            assertThat(denseJson).endsWith("\"")
            assertThat(denseJson).doesNotContain("hex:")

            // Binary serialization
            val bytes = build.skir.Serializers.bytes.toBytes(value)
            val restoredFromBytes = build.skir.Serializers.bytes.fromBytes(bytes.toByteArray())
            assertThat(restoredFromBytes).isEqualTo(value)
        }

        assertThat(build.skir.Serializers.bytes.fromJsonCode("0")).isEqualTo(ByteString.EMPTY)
    }

    @Test
    fun `test bytes serializer - readable flavor`() {
        val values =
            listOf(
                ByteString.EMPTY,
                "hello".encodeUtf8(),
                "world".encodeUtf8(),
                "Hello, 世界!".encodeUtf8(),
                ByteString.of(0, 255.toByte(), 127.toByte()),
            )

        for (value in values) {
            // Test READABLE flavor (should use hex with "hex:" prefix)
            val readableJson = build.skir.Serializers.bytes.toJsonCode(value, JsonFlavor.READABLE)
            val restoredFromReadable = build.skir.Serializers.bytes.fromJsonCode(readableJson)
            assertThat(restoredFromReadable).isEqualTo(value)

            // Readable should produce a hex string with "hex:" prefix
            assertThat(readableJson).startsWith("\"hex:")
            assertThat(readableJson).endsWith("\"")

            // Verify hex content is correct
            val expectedHex = "\"hex:${value.hex()}\""
            assertThat(readableJson).isEqualTo(expectedHex)
        }
    }

    @Test
    fun `test bytes serializer - fromJson handles both formats`() {
        val testBytes = "hello".encodeUtf8()

        // Test base64 format (dense)
        val base64Json = "\"${testBytes.base64()}\""
        val fromBase64 = build.skir.Serializers.bytes.fromJsonCode(base64Json)
        assertThat(fromBase64).isEqualTo(testBytes)

        // Test hex format (readable)
        val hexJson = "\"hex:${testBytes.hex()}\""
        val fromHex = build.skir.Serializers.bytes.fromJsonCode(hexJson)
        assertThat(fromHex).isEqualTo(testBytes)

        // Both should produce the same result
        assertThat(fromBase64).isEqualTo(fromHex)
    }

    @Test
    fun `test timestamp serializer - dense flavor`() {
        val instants =
            listOf(
                Instant.EPOCH,
                Instant.parse("2025-08-25T10:30:45Z"),
                Instant.parse("2000-01-01T00:00:00Z"),
                Instant.ofEpochMilli(System.currentTimeMillis()),
            )

        for (instant in instants) {
            val denseJson = build.skir.Serializers.timestamp.toJsonCode(instant)
            val restored = build.skir.Serializers.timestamp.fromJsonCode(denseJson)
            assertThat(restored).isEqualTo(instant)

            // Dense should produce a unix milliseconds number
            val denseJsonValue = denseJson.toLongOrNull()
            assertThat(denseJsonValue).isNotNull()

            // Binary serialization
            val bytes = build.skir.Serializers.timestamp.toBytes(instant)
            val restoredFromBytes = build.skir.Serializers.timestamp.fromBytes(bytes.toByteArray())
            assertThat(restoredFromBytes).isEqualTo(instant)
        }
    }

    @Test
    fun `test timestamp serializer - readable flavor`() {
        val instant = Instant.parse("2025-08-25T10:30:45Z")
        val readableJson = build.skir.Serializers.timestamp.toJsonCode(instant, JsonFlavor.READABLE)

        // Readable should produce an object with unix_millis and formatted
        assertThat(
            readableJson,
        ).isEqualTo(
            listOf(
                "{",
                "  \"unix_millis\": 1756117845000,",
                "  \"formatted\": \"2025-08-25T10:30:45Z\"",
                "}",
            ).joinToString(separator = "\n") { it },
        )

        val restoredFromReadable = build.skir.Serializers.timestamp.fromJsonCode(readableJson)
        assertThat(restoredFromReadable).isEqualTo(instant)
    }

    @Test
    fun `test edge cases and error handling`() {
        // Test empty string
        assertThat(build.skir.Serializers.string.fromJsonCode("\"\"")).isEqualTo("")

        // Test zero values
        assertThat(build.skir.Serializers.int32.fromJsonCode("0")).isEqualTo(0)
        assertThat(build.skir.Serializers.int64.fromJsonCode("0")).isEqualTo(0L)
        assertThat(build.skir.Serializers.float32.fromJsonCode("0.0")).isEqualTo(0.0f)
        assertThat(build.skir.Serializers.float64.fromJsonCode("0.0")).isEqualTo(0.0)

        // Test empty bytes
        assertThat(build.skir.Serializers.bytes.fromJsonCode("\"\"")).isEqualTo(ByteString.EMPTY)
    }

    @Test
    fun `test serialization roundtrip for all types`() {
        // Test that all serializers can handle roundtrip JSON serialization
        val testData =
            mapOf(
                build.skir.Serializers.bool to true,
                build.skir.Serializers.int32 to -42,
                build.skir.Serializers.int64 to 123456789L,
                build.skir.Serializers.hash64 to 987654321UL,
                build.skir.Serializers.float32 to 3.14f,
                build.skir.Serializers.float64 to 2.71828,
                build.skir.Serializers.string to "test string",
                build.skir.Serializers.bytes to "test bytes".encodeUtf8(),
                build.skir.Serializers.timestamp to Instant.parse("2025-08-25T12:00:00Z"),
            )

        testData.forEach { (serializer, value) ->
            @Suppress("UNCHECKED_CAST")
            val typedSerializer = serializer as Serializer<Any>

            // Test JSON roundtrip
            val json = typedSerializer.toJsonCode(value)
            val restored = typedSerializer.fromJsonCode(json)
            assertThat(restored).isEqualTo(value)

            // Test binary roundtrip
            val bytes = typedSerializer.toBytes(value)
            val restoredFromBytes = typedSerializer.fromBytes(bytes.toByteArray())
            assertThat(restoredFromBytes).isEqualTo(value)
        }
    }

    // Additional comprehensive tests for specific edge cases and binary format validation

    @Test
    fun `test int32 binary encoding specifics`() {
        // Test specific wire format encoding (includes "skir" prefix)
        val testCases =
            mapOf(
                0 to "736b697200",
                1 to "736b697201",
                231 to "736b6972e7",
                232 to "736b6972e8e800",
                257 to "736b6972e80101",
                65535 to "736b6972e8ffff",
                65536 to "736b6972e900000100",
                -1 to "736b6972ebff",
                -256 to "736b6972eb00",
                -257 to "736b6972ecfffe",
            )

        testCases.forEach { (value, expectedHex) ->
            val bytes = build.skir.Serializers.int32.toBytes(value)
            assertThat(bytes.hex()).isEqualTo(expectedHex)

            val restored = build.skir.Serializers.int32.fromBytes(bytes.toByteArray())
            assertThat(restored).isEqualTo(value)
        }
    }

    @Test
    fun `test float32 special values json serialization`() {
        val testCases =
            mapOf(
                Float.NaN to "\"NaN\"",
                Float.POSITIVE_INFINITY to "\"Infinity\"",
                Float.NEGATIVE_INFINITY to "\"-Infinity\"",
                0.0f to "0.0",
                -0.0f to "-0.0",
            )

        testCases.forEach { (value, expectedJson) ->
            val json = build.skir.Serializers.float32.toJsonCode(value)
            if (value.isNaN()) {
                // For NaN, just check that it deserializes correctly
                val restored = build.skir.Serializers.float32.fromJsonCode(json)
                assertThat(restored.isNaN()).isTrue()
            } else {
                val restored = build.skir.Serializers.float32.fromJsonCode(json)
                assertThat(restored).isEqualTo(value)
            }
        }
    }

    @Test
    fun `test float64 special values json serialization`() {
        val testCases =
            mapOf(
                Double.NaN to "\"NaN\"",
                Double.POSITIVE_INFINITY to "\"Infinity\"",
                Double.NEGATIVE_INFINITY to "\"-Infinity\"",
                0.0 to "0.0",
                -0.0 to "-0.0",
            )

        testCases.forEach { (value, expectedJson) ->
            val json = build.skir.Serializers.float64.toJsonCode(value)
            if (value.isNaN()) {
                // For NaN, just check that it deserializes correctly
                val restored = build.skir.Serializers.float64.fromJsonCode(json)
                assertThat(restored.isNaN()).isTrue()
            } else {
                val restored = build.skir.Serializers.float64.fromJsonCode(json)
                assertThat(restored).isEqualTo(value)
            }
        }
    }

    @Test
    fun `test int64 large number json serialization`() {
        // Test JavaScript safe integer boundaries
        val safeMax = 9007199254740992L // 2^53
        val safeMin = -9007199254740992L // -(2^53)

        // Values within safe range should be numbers
        val safeValue = 123456789L
        val safeJson = build.skir.Serializers.int64.toJsonCode(safeValue)
        assertThat(safeJson).isEqualTo("123456789")

        // Values outside safe range should be strings
        val unsafeValue = Long.MAX_VALUE
        val unsafeJson = build.skir.Serializers.int64.toJsonCode(unsafeValue)
        assertThat(unsafeJson).startsWith("\"")
        assertThat(unsafeJson).endsWith("\"")

        // Both should roundtrip correctly
        assertThat(build.skir.Serializers.int64.fromJsonCode(safeJson)).isEqualTo(safeValue)
        assertThat(build.skir.Serializers.int64.fromJsonCode(unsafeJson)).isEqualTo(unsafeValue)
    }

    @Test
    fun `test hash64 large number json serialization`() {
        // Test JavaScript safe integer boundaries for unsigned values
        val safeValue = 123456789UL
        val safeJson = build.skir.Serializers.hash64.toJsonCode(safeValue)
        assertThat(safeJson).isEqualTo("123456789")

        // Values outside safe range should be strings
        val unsafeValue = ULong.MAX_VALUE
        val unsafeJson = build.skir.Serializers.hash64.toJsonCode(unsafeValue)
        assertThat(unsafeJson).startsWith("\"")
        assertThat(unsafeJson).endsWith("\"")

        // Both should roundtrip correctly
        assertThat(build.skir.Serializers.hash64.fromJsonCode(safeJson)).isEqualTo(safeValue)
        assertThat(build.skir.Serializers.hash64.fromJsonCode(unsafeJson)).isEqualTo(unsafeValue)
    }

    @Test
    fun `test string encoding edge cases`() {
        val testCases =
            listOf(
                "" to "736b6972f2",
                "0" to "736b6972f30130",
                "A" to "736b6972f30141",
                "🚀" to "736b6972f304f09f9a80",
                "\u0000" to "736b6972f30100",
                "Hello\nWorld" to "736b6972f30b48656c6c6f0a576f726c64",
            )

        testCases.forEach { (value, expectedHex) ->
            val bytes = build.skir.Serializers.string.toBytes(value)
            assertThat(bytes.hex()).isEqualTo(expectedHex)

            val restored = build.skir.Serializers.string.fromBytes(bytes.toByteArray())
            assertThat(restored).isEqualTo(value)
        }
    }

    @Test
    fun `test bytes encoding edge cases`() {
        val testCases =
            listOf(
                ByteString.EMPTY to "736b6972f4",
                "A".encodeUtf8() to "736b6972f50141",
                ByteString.of(0, 255.toByte()) to "736b6972f50200ff",
            )

        testCases.forEach { (value, expectedHex) ->
            val bytes = build.skir.Serializers.bytes.toBytes(value)
            assertThat(bytes.hex()).isEqualTo(expectedHex)

            val restored = build.skir.Serializers.bytes.fromBytes(bytes.toByteArray())
            assertThat(restored).isEqualTo(value)

            // Test JSON serialization in both flavors
            val denseJson = build.skir.Serializers.bytes.toJsonCode(value)
            val readableJson = build.skir.Serializers.bytes.toJsonCode(value, JsonFlavor.READABLE)

            // Dense should be base64
            assertThat(denseJson).doesNotContain("hex:")
            assertThat(build.skir.Serializers.bytes.fromJsonCode(denseJson)).isEqualTo(value)

            // Readable should be hex with prefix
            assertThat(readableJson).startsWith("\"hex:")
            assertThat(build.skir.Serializers.bytes.fromJsonCode(readableJson)).isEqualTo(value)
        }
    }

    @Test
    fun `test instant clamping behavior`() {
        // Test that instants are clamped to valid JavaScript Date range
        val minValid = Instant.ofEpochMilli(-8640000000000000L)
        val maxValid = Instant.ofEpochMilli(8640000000000000L)

        // Test that these values roundtrip correctly
        val minBytes = build.skir.Serializers.timestamp.toBytes(minValid)
        val restoredMin = build.skir.Serializers.timestamp.fromBytes(minBytes.toByteArray())
        assertThat(restoredMin).isEqualTo(minValid)

        val maxBytes = build.skir.Serializers.timestamp.toBytes(maxValid)
        val restoredMax = build.skir.Serializers.timestamp.fromBytes(maxBytes.toByteArray())
        assertThat(restoredMax).isEqualTo(maxValid)
    }

    @Test
    fun `test instant binary encoding specifics`() {
        val testCases =
            mapOf(
                Instant.EPOCH to "736b697200",
                Instant.ofEpochMilli(1000) to "736b6972efe803000000000000",
                Instant.ofEpochMilli(-1000) to "736b6972ef18fcffffffffffff",
            )

        testCases.forEach { (instant, expectedHex) ->
            val bytes = build.skir.Serializers.timestamp.toBytes(instant)
            assertThat(bytes.hex()).isEqualTo(expectedHex)

            val restored = build.skir.Serializers.timestamp.fromBytes(bytes.toByteArray())
            assertThat(restored).isEqualTo(instant)
        }
    }

    @Test
    fun `test all serializers handle defaults correctly`() {
        // Test that default values roundtrip correctly through serialization
        val defaultTests =
            mapOf(
                build.skir.Serializers.bool to false,
                build.skir.Serializers.int32 to 0,
                build.skir.Serializers.int64 to 0L,
                build.skir.Serializers.hash64 to 0UL,
                build.skir.Serializers.float32 to 0.0f,
                build.skir.Serializers.float64 to 0.0,
                build.skir.Serializers.string to "",
                build.skir.Serializers.bytes to ByteString.EMPTY,
                build.skir.Serializers.timestamp to Instant.EPOCH,
            )

        defaultTests.forEach { (serializer, defaultValue) ->
            @Suppress("UNCHECKED_CAST")
            val typedSerializer = serializer as Serializer<Any>

            // Test JSON roundtrip for default values
            val json = typedSerializer.toJsonCode(defaultValue)
            val restoredFromJson = typedSerializer.fromJsonCode(json)
            assertThat(restoredFromJson).isEqualTo(defaultValue)

            // Test binary roundtrip for default values
            val bytes = typedSerializer.toBytes(defaultValue)
            val restoredFromBytes = typedSerializer.fromBytes(bytes.toByteArray())
            assertThat(restoredFromBytes).isEqualTo(defaultValue)
        }
    }

    @Test
    fun `test optional serializer with non-null values`() {
        // Test optional serializer with various non-null values
        val intOptional = build.skir.Serializers.optional(build.skir.Serializers.int32)
        val stringOptional = build.skir.Serializers.optional(build.skir.Serializers.string)
        val boolOptional = build.skir.Serializers.optional(build.skir.Serializers.bool)
        val bytesOptional = build.skir.Serializers.optional(build.skir.Serializers.bytes)
        val instantOptional = build.skir.Serializers.optional(build.skir.Serializers.timestamp)

        // Test non-null values
        val testValue = 42
        val jsonCode = intOptional.toJsonCode(testValue)
        val restored = intOptional.fromJsonCode(jsonCode)
        assertThat(restored).isEqualTo(testValue)

        val bytes = intOptional.toBytes(testValue)
        val restoredFromBytes = intOptional.fromBytes(bytes.toByteArray())
        assertThat(restoredFromBytes).isEqualTo(testValue)

        // Test string
        val testString = "hello world"
        val stringJson = stringOptional.toJsonCode(testString)
        val restoredString = stringOptional.fromJsonCode(stringJson)
        assertThat(restoredString).isEqualTo(testString)

        val stringBytes = stringOptional.toBytes(testString)
        val restoredStringFromBytes = stringOptional.fromBytes(stringBytes.toByteArray())
        assertThat(restoredStringFromBytes).isEqualTo(testString)

        // Test bool
        val testBool = true
        val boolJson = boolOptional.toJsonCode(testBool)
        val restoredBool = boolOptional.fromJsonCode(boolJson)
        assertThat(restoredBool).isEqualTo(testBool)

        val boolBytes = boolOptional.toBytes(testBool)
        val restoredBoolFromBytes = boolOptional.fromBytes(boolBytes.toByteArray())
        assertThat(restoredBoolFromBytes).isEqualTo(testBool)

        // Test bytes
        val testBytes = "test data".encodeUtf8()
        val bytesJson = bytesOptional.toJsonCode(testBytes)
        val restoredBytes = bytesOptional.fromJsonCode(bytesJson)
        assertThat(restoredBytes).isEqualTo(testBytes)

        val bytesBinary = bytesOptional.toBytes(testBytes)
        val restoredBytesFromBinary = bytesOptional.fromBytes(bytesBinary.toByteArray())
        assertThat(restoredBytesFromBinary).isEqualTo(testBytes)

        // Test instant
        val testTimestamp = Instant.parse("2025-08-25T12:00:00Z")
        val instantJson = instantOptional.toJsonCode(testTimestamp)
        val restoredTimestamp = instantOptional.fromJsonCode(instantJson)
        assertThat(restoredTimestamp).isEqualTo(testTimestamp)

        val instantBytes = instantOptional.toBytes(testTimestamp)
        val restoredTimestampFromBytes = instantOptional.fromBytes(instantBytes.toByteArray())
        assertThat(restoredTimestampFromBytes).isEqualTo(testTimestamp)
    }

    @Test
    fun `test optional serializer with null values`() {
        // Test optional serializer with null values
        val intOptional = build.skir.Serializers.optional(build.skir.Serializers.int32)
        val stringOptional = build.skir.Serializers.optional(build.skir.Serializers.string)
        val boolOptional = build.skir.Serializers.optional(build.skir.Serializers.bool)
        val bytesOptional = build.skir.Serializers.optional(build.skir.Serializers.bytes)
        val instantOptional = build.skir.Serializers.optional(build.skir.Serializers.timestamp)

        // Test null values in JSON
        val nullJson = intOptional.toJsonCode(null)
        assertThat(nullJson).isEqualTo("null")
        val restoredNull = intOptional.fromJsonCode(nullJson)
        assertThat(restoredNull).isEqualTo(null)

        // Test null values in binary format
        val nullBytes = intOptional.toBytes(null)
        assertThat(nullBytes.hex()).isEqualTo("736b6972ff") // Should end with 0xFF for null
        val restoredNullFromBytes = intOptional.fromBytes(nullBytes.toByteArray())
        assertThat(restoredNullFromBytes).isEqualTo(null)

        // Test all types with null
        listOf(intOptional, stringOptional, boolOptional, bytesOptional, instantOptional).forEach { serializer ->
            @Suppress("UNCHECKED_CAST")
            val typedSerializer = serializer as Serializer<Any?>

            val json = typedSerializer.toJsonCode(null)
            assertThat(json).isEqualTo("null")
            assertThat(typedSerializer.fromJsonCode(json)).isEqualTo(null)

            val bytes = typedSerializer.toBytes(null)
            assertThat(bytes.hex().endsWith("ff")).isTrue()
            assertThat(typedSerializer.fromBytes(bytes.toByteArray())).isEqualTo(null)
        }
    }

    @Test
    fun `test optional serializer json flavors`() {
        val intOptional = build.skir.Serializers.optional(build.skir.Serializers.int32)
        val instantOptional = build.skir.Serializers.optional(build.skir.Serializers.timestamp)
        val boolOptional = build.skir.Serializers.optional(build.skir.Serializers.bool)

        // Test non-null values with different flavors
        val testInt = 42
        val denseIntJson = intOptional.toJsonCode(testInt)
        val readableIntJson = intOptional.toJsonCode(testInt, JsonFlavor.READABLE)
        assertThat(readableIntJson).isEqualTo(denseIntJson) // Should be the same for int32

        // Test instant with different flavors
        val testTimestamp = Instant.parse("2025-08-25T12:00:00Z")
        val denseTimestampJson = instantOptional.toJsonCode(testTimestamp)
        val readableTimestampJson = instantOptional.toJsonCode(testTimestamp, JsonFlavor.READABLE)
        // Dense should be a number, readable should be an object
        assertThat(denseTimestampJson.toLongOrNull() != null).isTrue()
        assertThat(readableTimestampJson.contains("unix_millis")).isTrue()

        // Test bool with different flavors
        val testBool = true
        val denseBoolJson = boolOptional.toJsonCode(testBool)
        val readableBoolJson = boolOptional.toJsonCode(testBool, JsonFlavor.READABLE)
        assertThat(denseBoolJson).isEqualTo("1") // Dense should be "1"
        assertThat(readableBoolJson).isEqualTo("true") // Readable should be "true"

        // Test null with different flavors (should always be "null")
        val nullDense = intOptional.toJsonCode(null)
        val nullReadable = intOptional.toJsonCode(null, JsonFlavor.READABLE)
        assertThat(nullDense).isEqualTo("null")
        assertThat(nullReadable).isEqualTo("null")
    }

    @Test
    fun `test optional serializer edge cases`() {
        val intOptional = build.skir.Serializers.optional(build.skir.Serializers.int32)
        val stringOptional = build.skir.Serializers.optional(build.skir.Serializers.string)
        val bytesOptional = build.skir.Serializers.optional(build.skir.Serializers.bytes)

        // Test edge case values
        val testCases =
            listOf(
                intOptional to listOf(0, Int.MAX_VALUE, Int.MIN_VALUE, null),
                stringOptional to listOf("", "null", "undefined", "false", "0", null),
                bytesOptional to listOf(ByteString.EMPTY, "null".encodeUtf8(), null),
            )

        testCases.forEach { (serializer, values) ->
            values.forEach { value ->
                @Suppress("UNCHECKED_CAST")
                val typedSerializer = serializer as Serializer<Any?>

                // Test JSON roundtrip
                val json = typedSerializer.toJsonCode(value)
                val restoredFromJson = typedSerializer.fromJsonCode(json)
                assertThat(restoredFromJson).isEqualTo(value)

                // Test binary roundtrip
                val bytes = typedSerializer.toBytes(value)
                val restoredFromBytes = typedSerializer.fromBytes(bytes.toByteArray())
                assertThat(restoredFromBytes).isEqualTo(value)
            }
        }
    }

    @Test
    fun `test optional serializer binary format specifics`() {
        val intOptional = build.skir.Serializers.optional(build.skir.Serializers.int32)

        // Test specific binary encodings
        val testCases =
            mapOf(
                null to "736b6972ff",
                0 to "736b697200",
                42 to "736b69722a",
                -1 to "736b6972ebff",
            )

        testCases.forEach { (value, expectedHex) ->
            val bytes = intOptional.toBytes(value)
            assertThat(bytes.hex()).isEqualTo(expectedHex)

            val restored = intOptional.fromBytes(bytes.toByteArray())
            assertThat(restored).isEqualTo(value)
        }
    }

    @Test
    fun `test nested optional serializers`() {
        // While the API prevents double-optional, we can test complex scenarios
        val intOptional = build.skir.Serializers.optional(build.skir.Serializers.int32)
        val stringOptional = build.skir.Serializers.optional(build.skir.Serializers.string)
        val instantOptional = build.skir.Serializers.optional(build.skir.Serializers.timestamp)

        // Test combinations of optional serializers with different types
        val testScenarios =
            listOf(
                Triple(intOptional, 42, null),
                Triple(intOptional, null, 42),
                Triple(stringOptional, "test", null),
                Triple(stringOptional, null, "test"),
                Triple(instantOptional, Instant.parse("2025-08-25T12:00:00Z"), null),
                Triple(instantOptional, null, Instant.parse("2025-08-25T12:00:00Z")),
            )

        testScenarios.forEach { (serializer, value1, value2) ->
            @Suppress("UNCHECKED_CAST")
            val typedSerializer = serializer as Serializer<Any?>

            // Test that different values produce different results
            val json1 = typedSerializer.toJsonCode(value1)
            val json2 = typedSerializer.toJsonCode(value2)

            if (value1 != value2) {
                assertThat(json1 != json2).isTrue()
            }

            // Test roundtrip for both values
            assertThat(typedSerializer.fromJsonCode(json1)).isEqualTo(value1)
            assertThat(typedSerializer.fromJsonCode(json2)).isEqualTo(value2)

            // Test binary serialization
            val bytes1 = typedSerializer.toBytes(value1)
            val bytes2 = typedSerializer.toBytes(value2)

            if (value1 != value2) {
                assertThat(bytes1 != bytes2).isTrue()
            }

            assertThat(typedSerializer.fromBytes(bytes1.toByteArray())).isEqualTo(value1)
            assertThat(typedSerializer.fromBytes(bytes2.toByteArray())).isEqualTo(value2)
        }
    }

    @Test
    fun `test optional serializer with all primitive types`() {
        // Test that optional works correctly with all primitive serializers
        val optionalSerializers =
            mapOf(
                "bool" to build.skir.Serializers.optional(build.skir.Serializers.bool),
                "int32" to build.skir.Serializers.optional(build.skir.Serializers.int32),
                "int64" to build.skir.Serializers.optional(build.skir.Serializers.int64),
                "hash64" to build.skir.Serializers.optional(build.skir.Serializers.hash64),
                "float32" to build.skir.Serializers.optional(build.skir.Serializers.float32),
                "float64" to build.skir.Serializers.optional(build.skir.Serializers.float64),
                "string" to build.skir.Serializers.optional(build.skir.Serializers.string),
                "bytes" to build.skir.Serializers.optional(build.skir.Serializers.bytes),
                "instant" to build.skir.Serializers.optional(build.skir.Serializers.timestamp),
            )

        val testValues =
            mapOf(
                "bool" to listOf(true, false, null),
                "int32" to listOf(0, 42, -1, Int.MAX_VALUE, Int.MIN_VALUE, null),
                "int64" to listOf(0L, 42L, -1L, Long.MAX_VALUE, Long.MIN_VALUE, null),
                "hash64" to listOf(0UL, 42UL, ULong.MAX_VALUE, null),
                "float32" to listOf(0.0f, 3.14f, Float.NaN, Float.POSITIVE_INFINITY, Float.NEGATIVE_INFINITY, null),
                "float64" to listOf(0.0, 3.14159, Double.NaN, Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY, null),
                "string" to listOf("", "hello", "world", "🚀", null),
                "bytes" to listOf(ByteString.EMPTY, "test".encodeUtf8(), null),
                "instant" to listOf(Instant.EPOCH, Instant.parse("2025-08-25T12:00:00Z"), null),
            )

        optionalSerializers.forEach { (typeName, serializer) ->
            val values = testValues[typeName] ?: error("No test values for $typeName")

            values.forEach { value ->
                @Suppress("UNCHECKED_CAST")
                val typedSerializer = serializer as Serializer<Any?>

                // Test JSON roundtrip
                val json = typedSerializer.toJsonCode(value)
                val restoredFromJson = typedSerializer.fromJsonCode(json)

                if (typeName == "float32" && value is Float && value.isNaN()) {
                    assertThat((restoredFromJson as Float).isNaN()).isTrue()
                } else if (typeName == "float64" && value is Double && value.isNaN()) {
                    assertThat((restoredFromJson as Double).isNaN()).isTrue()
                } else {
                    assertThat(restoredFromJson).isEqualTo(value)
                }

                // Test binary roundtrip
                val bytes = typedSerializer.toBytes(value)
                val restoredFromBytes = typedSerializer.fromBytes(bytes.toByteArray())

                if (typeName == "float32" && value is Float && value.isNaN()) {
                    assertThat((restoredFromBytes as Float).isNaN()).isTrue()
                } else if (typeName == "float64" && value is Double && value.isNaN()) {
                    assertThat((restoredFromBytes as Double).isNaN()).isTrue()
                } else {
                    assertThat(restoredFromBytes).isEqualTo(value)
                }
            }
        }
    }

    @Test
    fun `test list serializer with empty arrays`() {
        // Test list serializers with empty arrays
        val intArraySerializer = build.skir.Serializers.list(build.skir.Serializers.int32)
        val stringArraySerializer = build.skir.Serializers.list(build.skir.Serializers.string)
        val boolArraySerializer = build.skir.Serializers.list(build.skir.Serializers.bool)

        // Test empty arrays
        val emptyIntArray = emptyList<Int>()
        val emptyStringArray = emptyList<String>()
        val emptyBoolArray = emptyList<Boolean>()

        // JSON tests
        val emptyIntJson = intArraySerializer.toJsonCode(emptyIntArray)
        assertThat(emptyIntJson).isEqualTo("[]")
        assertThat(intArraySerializer.fromJsonCode(emptyIntJson)).isEqualTo(emptyIntArray)

        val emptyStringJson = stringArraySerializer.toJsonCode(emptyStringArray)
        assertThat(emptyStringJson).isEqualTo("[]")
        assertThat(stringArraySerializer.fromJsonCode(emptyStringJson)).isEqualTo(emptyStringArray)

        val emptyBoolJson = boolArraySerializer.toJsonCode(emptyBoolArray)
        assertThat(emptyBoolJson).isEqualTo("[]")
        assertThat(boolArraySerializer.fromJsonCode(emptyBoolJson)).isEqualTo(emptyBoolArray)

        // Binary tests - empty arrays should have specific wire format
        val emptyIntBytes = intArraySerializer.toBytes(emptyIntArray)
        assertThat(emptyIntBytes.hex()) // Should be skir prefix + 0xF6 (246).isEqualTo("736b6972f6")
        assertThat(intArraySerializer.fromBytes(emptyIntBytes.toByteArray())).isEqualTo(emptyIntArray)

        val emptyStringBytes = stringArraySerializer.toBytes(emptyStringArray)
        assertThat(emptyStringBytes.hex()).isEqualTo("736b6972f6")
        assertThat(stringArraySerializer.fromBytes(emptyStringBytes.toByteArray())).isEqualTo(emptyStringArray)

        val emptyBoolBytes = boolArraySerializer.toBytes(emptyBoolArray)
        assertThat(emptyBoolBytes.hex()).isEqualTo("736b6972f6")
        assertThat(boolArraySerializer.fromBytes(emptyBoolBytes.toByteArray())).isEqualTo(emptyBoolArray)

        // Test that fromJsonCode("0") also works for empty arrays
        assertThat(intArraySerializer.fromJsonCode("0")).isEqualTo(emptyIntArray)
        assertThat(stringArraySerializer.fromJsonCode("0")).isEqualTo(emptyStringArray)
        assertThat(boolArraySerializer.fromJsonCode("0")).isEqualTo(emptyBoolArray)
    }

    @Test
    fun `test list serializer with small arrays`() {
        val intArraySerializer = build.skir.Serializers.list(build.skir.Serializers.int32)
        val stringArraySerializer = build.skir.Serializers.list(build.skir.Serializers.string)

        // Test arrays with 1-3 elements (should use wire bytes 247-249)
        val singleIntArray = listOf(42)
        val doubleIntArray = listOf(1, 2)
        val tripleIntArray = listOf(10, 20, 30)

        // JSON tests
        assertThat(intArraySerializer.toJsonCode(singleIntArray)).isEqualTo("[42]")
        assertThat(intArraySerializer.toJsonCode(doubleIntArray)).isEqualTo("[1,2]")
        assertThat(intArraySerializer.toJsonCode(tripleIntArray)).isEqualTo("[10,20,30]")

        assertThat(intArraySerializer.fromJsonCode("[42]")).isEqualTo(singleIntArray)
        assertThat(intArraySerializer.fromJsonCode("[1,2]")).isEqualTo(doubleIntArray)
        assertThat(intArraySerializer.fromJsonCode("[10,20,30]")).isEqualTo(tripleIntArray)

        // Binary tests
        val singleBytes = intArraySerializer.toBytes(singleIntArray)
        assertThat(singleBytes.hex()).startsWith("736b6972f7")
        assertThat(intArraySerializer.fromBytes(singleBytes.toByteArray())).isEqualTo(singleIntArray)

        val doubleBytes = intArraySerializer.toBytes(doubleIntArray)
        assertThat(doubleBytes.hex()).startsWith("736b6972f8")
        assertThat(intArraySerializer.fromBytes(doubleBytes.toByteArray())).isEqualTo(doubleIntArray)

        val tripleBytes = intArraySerializer.toBytes(tripleIntArray)
        assertThat(tripleBytes.hex()).startsWith("736b6972f9")
        assertThat(intArraySerializer.fromBytes(tripleBytes.toByteArray())).isEqualTo(tripleIntArray)

        // Test with strings
        val stringArray = listOf("hello", "world")
        val stringJson = stringArraySerializer.toJsonCode(stringArray)
        assertThat(stringJson).isEqualTo(listOf("\"hello\"", "\"world\"").joinToString(",", "[", "]"))
        assertThat(stringArraySerializer.fromJsonCode(stringJson)).isEqualTo(stringArray)

        val stringBytes = stringArraySerializer.toBytes(stringArray)
        assertThat(stringBytes.hex()).startsWith("736b6972f8")
        assertThat(stringArraySerializer.fromBytes(stringBytes.toByteArray())).isEqualTo(stringArray)
    }

    @Test
    fun `test list serializer with large arrays`() {
        val intArraySerializer = build.skir.Serializers.list(build.skir.Serializers.int32)

        // Test arrays with more than 3 elements (should use wire byte 250 + length prefix)
        val largeArray = listOf(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
        val veryLargeArray = (1..1000).toList()

        // JSON tests
        val largeJson = intArraySerializer.toJsonCode(largeArray)
        assertThat(largeJson).startsWith("[")
        assertThat(largeJson.endsWith("]"))
        assertThat(intArraySerializer.fromJsonCode(largeJson)).isEqualTo(largeArray)

        val veryLargeJson = intArraySerializer.toJsonCode(veryLargeArray)
        assertThat(veryLargeJson).startsWith("[")
        assertThat(veryLargeJson).endsWith("]")
        assertThat(intArraySerializer.fromJsonCode(veryLargeJson)).isEqualTo(veryLargeArray)

        // Binary tests
        val largeBytes = intArraySerializer.toBytes(largeArray)
        assertThat(largeBytes.hex()).startsWith("736b6972fa")
        assertThat(intArraySerializer.fromBytes(largeBytes.toByteArray())).isEqualTo(largeArray)

        val veryLargeBytes = intArraySerializer.toBytes(veryLargeArray)
        assertThat(veryLargeBytes.hex()).startsWith("736b6972fa")
        assertThat(intArraySerializer.fromBytes(veryLargeBytes.toByteArray())).isEqualTo(veryLargeArray)
    }

    @Test
    fun `test list serializer with different element types`() {
        // Test list serializers with all primitive types
        val boolArraySerializer = build.skir.Serializers.list(build.skir.Serializers.bool)
        val int32ArraySerializer = build.skir.Serializers.list(build.skir.Serializers.int32)
        val int64ArraySerializer = build.skir.Serializers.list(build.skir.Serializers.int64)
        val hash64ArraySerializer = build.skir.Serializers.list(build.skir.Serializers.hash64)
        val float32ArraySerializer = build.skir.Serializers.list(build.skir.Serializers.float32)
        val float64ArraySerializer = build.skir.Serializers.list(build.skir.Serializers.float64)
        val stringArraySerializer = build.skir.Serializers.list(build.skir.Serializers.string)
        val bytesArraySerializer = build.skir.Serializers.list(build.skir.Serializers.bytes)
        val instantArraySerializer = build.skir.Serializers.list(build.skir.Serializers.timestamp)

        // Test data for each type
        val boolArray = listOf(true, false, true)
        val int32Array = listOf(0, -1, 42, Int.MAX_VALUE, Int.MIN_VALUE)
        val int64Array = listOf(0L, -1L, 42L, Long.MAX_VALUE, Long.MIN_VALUE)
        val hash64Array = listOf(0UL, 1UL, 42UL, ULong.MAX_VALUE)
        val float32Array = listOf(0.0f, 1.0f, -1.0f, 3.14f, Float.NaN, Float.POSITIVE_INFINITY)
        val float64Array = listOf(0.0, 1.0, -1.0, 3.14159, Double.NaN, Double.NEGATIVE_INFINITY)
        val stringArray = listOf("", "hello", "world", "🚀", "Hello, 世界!")
        val bytesArray = listOf(ByteString.EMPTY, "test".encodeUtf8(), "hello world".encodeUtf8())
        val instantArray = listOf(Instant.EPOCH, Instant.parse("2025-08-25T12:00:00Z"))

        val testCases =
            listOf(
                Triple(boolArraySerializer, boolArray, "bool"),
                Triple(int32ArraySerializer, int32Array, "int32"),
                Triple(int64ArraySerializer, int64Array, "int64"),
                Triple(hash64ArraySerializer, hash64Array, "hash64"),
                Triple(float32ArraySerializer, float32Array, "float32"),
                Triple(float64ArraySerializer, float64Array, "float64"),
                Triple(stringArraySerializer, stringArray, "string"),
                Triple(bytesArraySerializer, bytesArray, "bytes"),
                Triple(instantArraySerializer, instantArray, "instant"),
            )

        testCases.forEach { (serializer, list, typeName) ->
            @Suppress("UNCHECKED_CAST")
            val typedSerializer = serializer as Serializer<List<Any>>

            val typedArray = list as List<Any>

            // JSON roundtrip
            val json = typedSerializer.toJsonCode(typedArray)
            val restoredFromJson = typedSerializer.fromJsonCode(json)

            // Special handling for NaN values in float arrays
            if (typeName == "float32" || typeName == "float64") {
                assertThat(restoredFromJson.size).isEqualTo(typedArray.size)
                typedArray.zip(restoredFromJson).forEach { (original, restored) ->
                    if (original is Float && original.isNaN()) {
                        assertThat((restored as Float).isNaN()).isTrue()
                    } else if (original is Double && original.isNaN()) {
                        assertThat((restored as Double).isNaN()).isTrue()
                    } else {
                        assertThat(restored).isEqualTo(original)
                    }
                }
            } else {
                assertThat(restoredFromJson).isEqualTo(typedArray)
            }

            // Binary roundtrip
            val bytes = typedSerializer.toBytes(typedArray)
            val restoredFromBytes = typedSerializer.fromBytes(bytes.toByteArray())

            if (typeName == "float32" || typeName == "float64") {
                assertThat(restoredFromBytes.size).isEqualTo(typedArray.size)
                typedArray.zip(restoredFromBytes).forEach { (original, restored) ->
                    if (original is Float && original.isNaN()) {
                        assertThat((restored as Float).isNaN()).isTrue()
                    } else if (original is Double && original.isNaN()) {
                        assertThat((restored as Double).isNaN()).isTrue()
                    } else {
                        assertThat(restored).isEqualTo(original)
                    }
                }
            } else {
                assertThat(restoredFromBytes).isEqualTo(typedArray)
            }
        }
    }

    @Test
    fun `test nested list serializers`() {
        val intArraySerializer = build.skir.Serializers.list(build.skir.Serializers.int32)
        val nestedIntArraySerializer = build.skir.Serializers.list(intArraySerializer)

        // Test list of arrays
        val nestedArray =
            listOf(
                listOf(1, 2, 3),
                listOf(4, 5),
                emptyList(),
                listOf(6),
            )

        // JSON roundtrip
        val json = nestedIntArraySerializer.toJsonCode(nestedArray)
        assertThat(json.startsWith("[[") || json.startsWith("[ [")).isTrue()
        val restoredFromJson = nestedIntArraySerializer.fromJsonCode(json)
        assertThat(restoredFromJson).isEqualTo(nestedArray)

        // Binary roundtrip
        val bytes = nestedIntArraySerializer.toBytes(nestedArray)
        assertThat(bytes.hex().startsWith("736b6972")).isTrue()
        val restoredFromBytes = nestedIntArraySerializer.fromBytes(bytes.toByteArray())
        assertThat(restoredFromBytes).isEqualTo(nestedArray)

        // Test deeply nested arrays
        val deeplyNestedArraySerializer = build.skir.Serializers.list(nestedIntArraySerializer)
        val deeplyNestedArray =
            listOf(
                listOf(listOf(1, 2), listOf(3, 4)),
                listOf(listOf(5), emptyList()),
            )

        val deepJson = deeplyNestedArraySerializer.toJsonCode(deeplyNestedArray)
        val restoredDeepFromJson = deeplyNestedArraySerializer.fromJsonCode(deepJson)
        assertThat(restoredDeepFromJson).isEqualTo(deeplyNestedArray)

        val deepBytes = deeplyNestedArraySerializer.toBytes(deeplyNestedArray)
        val restoredDeepFromBytes = deeplyNestedArraySerializer.fromBytes(deepBytes.toByteArray())
        assertThat(restoredDeepFromBytes).isEqualTo(deeplyNestedArray)
    }

    @Test
    fun `test list serializer with optional elements`() {
        val optionalIntSerializer = build.skir.Serializers.optional(build.skir.Serializers.int32)
        val optionalIntArraySerializer = build.skir.Serializers.list(optionalIntSerializer)

        // Test list with optional elements (some null, some not)
        val mixedArray = listOf(1, null, 42, null, 0)

        // JSON tests
        val json = optionalIntArraySerializer.toJsonCode(mixedArray)
        assertThat(json.contains("null")).isTrue()
        val restoredFromJson = optionalIntArraySerializer.fromJsonCode(json)
        assertThat(restoredFromJson).isEqualTo(mixedArray)

        // Binary tests
        val bytes = optionalIntArraySerializer.toBytes(mixedArray)
        val restoredFromBytes = optionalIntArraySerializer.fromBytes(bytes.toByteArray())
        assertThat(restoredFromBytes).isEqualTo(mixedArray)

        // Test all null list
        val allNullArray = listOf<Int?>(null, null, null)
        val allNullJson = optionalIntArraySerializer.toJsonCode(allNullArray)
        assertThat(allNullJson).isEqualTo("[null,null,null]")
        assertThat(optionalIntArraySerializer.fromJsonCode(allNullJson)).isEqualTo(allNullArray)

        val allNullBytes = optionalIntArraySerializer.toBytes(allNullArray)
        assertThat(optionalIntArraySerializer.fromBytes(allNullBytes.toByteArray())).isEqualTo(allNullArray)

        // Test no null list
        val noNullArray = listOf<Int?>(1, 2, 3)
        val noNullJson = optionalIntArraySerializer.toJsonCode(noNullArray)
        assertThat(noNullJson).isEqualTo("[1,2,3]")
        assertThat(optionalIntArraySerializer.fromJsonCode(noNullJson)).isEqualTo(noNullArray)

        val noNullBytes = optionalIntArraySerializer.toBytes(noNullArray)
        assertThat(optionalIntArraySerializer.fromBytes(noNullBytes.toByteArray())).isEqualTo(noNullArray)
    }

    @Test
    fun `test list serializer edge cases`() {
        val intArraySerializer = build.skir.Serializers.list(build.skir.Serializers.int32)
        val stringArraySerializer = build.skir.Serializers.list(build.skir.Serializers.string)

        // Test arrays with edge case values
        val edgeCaseIntArray = listOf(0, -1, 1, Int.MAX_VALUE, Int.MIN_VALUE, 232, 65536)
        val edgeCaseStringArray = listOf("", "0", "null", "false", "true", "[]", "{}")

        // Test roundtrips
        val intJson = intArraySerializer.toJsonCode(edgeCaseIntArray)
        assertThat(intArraySerializer.fromJsonCode(intJson)).isEqualTo(edgeCaseIntArray)
        val intBytes = intArraySerializer.toBytes(edgeCaseIntArray)
        assertThat(intArraySerializer.fromBytes(intBytes.toByteArray())).isEqualTo(edgeCaseIntArray)

        val stringJson = stringArraySerializer.toJsonCode(edgeCaseStringArray)
        assertThat(stringArraySerializer.fromJsonCode(stringJson)).isEqualTo(edgeCaseStringArray)
        val stringBytes = stringArraySerializer.toBytes(edgeCaseStringArray)
        assertThat(stringArraySerializer.fromBytes(stringBytes.toByteArray())).isEqualTo(edgeCaseStringArray)

        // Test very large list (boundary testing)
        val boundaryArray = (1..100).toList()
        val boundaryJson = intArraySerializer.toJsonCode(boundaryArray)
        assertThat(intArraySerializer.fromJsonCode(boundaryJson)).isEqualTo(boundaryArray)
        val boundaryBytes = intArraySerializer.toBytes(boundaryArray)
        assertThat(intArraySerializer.fromBytes(boundaryBytes.toByteArray())).isEqualTo(boundaryArray)

        // Test single element arrays with special values
        val singleZeroArray = listOf(0)
        val singleZeroJson = intArraySerializer.toJsonCode(singleZeroArray)
        assertThat(singleZeroJson).isEqualTo("[0]")
        assertThat(intArraySerializer.fromJsonCode(singleZeroJson)).isEqualTo(singleZeroArray)

        val singleEmptyStringArray = listOf("")
        val singleEmptyStringJson = stringArraySerializer.toJsonCode(singleEmptyStringArray)
        assertThat(singleEmptyStringJson).isEqualTo("[\"\"]")
        assertThat(stringArraySerializer.fromJsonCode(singleEmptyStringJson)).isEqualTo(singleEmptyStringArray)
    }

    @Test
    fun `test list serializer binary format specifics`() {
        val intArraySerializer = build.skir.Serializers.list(build.skir.Serializers.int32)

        // Test specific binary format expectations based on list size
        val testCases =
            mapOf(
                emptyList<Int>() to "736b6972f6",
                listOf(1) to "736b6972f701",
                listOf(1, 2) to "736b6972f80102",
                listOf(1, 2, 3) to "736b6972f9010203",
            )

        testCases.forEach { (list, expectedHexPrefix) ->
            val bytes = intArraySerializer.toBytes(list)
            if (list.size <= 3) {
                assertThat(bytes.hex()).isEqualTo(expectedHexPrefix)
            } else {
                assertThat(bytes.hex().startsWith("736b6972fa")).isTrue()
            }
            assertThat(intArraySerializer.fromBytes(bytes.toByteArray())).isEqualTo(list)
        }

        // Test large list format
        val largeArray = (1..10).toList()
        val largeBytes = intArraySerializer.toBytes(largeArray)
        assertThat(largeBytes.hex().startsWith("736b6972fa0a")).isTrue()
        assertThat(intArraySerializer.fromBytes(largeBytes.toByteArray())).isEqualTo(largeArray)
    }

    @Test
    fun `test list serializer performance with large arrays`() {
        val intArraySerializer = build.skir.Serializers.list(build.skir.Serializers.int32)

        // Test with reasonably large arrays to ensure no stack overflow or performance issues
        val mediumArray = (1..1000).toList()
        val largeArray = (1..10000).toList()

        // JSON roundtrip
        val mediumJson = intArraySerializer.toJsonCode(mediumArray)
        assertThat(mediumJson.length > 1000).isTrue()
        assertThat(intArraySerializer.fromJsonCode(mediumJson)).isEqualTo(mediumArray)

        val largeJson = intArraySerializer.toJsonCode(largeArray)
        assertThat(largeJson.length > 10000).isTrue()
        assertThat(intArraySerializer.fromJsonCode(largeJson)).isEqualTo(largeArray)

        // Binary roundtrip
        val mediumBytes = intArraySerializer.toBytes(mediumArray)
        assertThat(mediumBytes.size > 1000).isTrue()
        assertThat(intArraySerializer.fromBytes(mediumBytes.toByteArray())).isEqualTo(mediumArray)

        val largeBytes = intArraySerializer.toBytes(largeArray)
        assertThat(largeBytes.size > 10000).isTrue()
        assertThat(intArraySerializer.fromBytes(largeBytes.toByteArray())).isEqualTo(largeArray)
    }

    @Test
    fun `test toStringImpl - int32`() {
        assertThat(toStringImpl(-2, build.skir.Serializers.int32.impl)).isEqualTo("-2")
        assertThat(toStringImpl(300, build.skir.Serializers.int32.impl)).isEqualTo("300")
    }

    @Test
    fun `test toStringImpl - int64`() {
        assertThat(toStringImpl(-2L, build.skir.Serializers.int64.impl)).isEqualTo("-2L")
    }

    @Test
    fun `test toStringImpl - hash64`() {
        assertThat(toStringImpl(2UL, build.skir.Serializers.hash64.impl)).isEqualTo("2UL")
    }

    @Test
    fun `test toStringImpl - float32`() {
        assertThat(toStringImpl(3.14F, build.skir.Serializers.float32.impl)).isEqualTo("3.14F")
        assertThat(toStringImpl(Float.NaN, build.skir.Serializers.float32.impl)).isEqualTo("Float.NaN")
        assertThat(
            toStringImpl(Float.POSITIVE_INFINITY, build.skir.Serializers.float32.impl),
        ).isEqualTo("Float.POSITIVE_INFINITY")
        assertThat(
            toStringImpl(Float.NEGATIVE_INFINITY, build.skir.Serializers.float32.impl),
        ).isEqualTo("Float.NEGATIVE_INFINITY")
    }

    @Test
    fun `test toStringImpl - float64`() {
        assertThat(toStringImpl(3.14, build.skir.Serializers.float64.impl)).isEqualTo("3.14")
        assertThat(toStringImpl(Double.NaN, build.skir.Serializers.float64.impl)).isEqualTo("Double.NaN")
        assertThat(
            toStringImpl(Double.POSITIVE_INFINITY, build.skir.Serializers.float64.impl),
        ).isEqualTo("Double.POSITIVE_INFINITY")
        assertThat(
            toStringImpl(Double.NEGATIVE_INFINITY, build.skir.Serializers.float64.impl),
        ).isEqualTo("Double.NEGATIVE_INFINITY")
    }

    @Test
    fun `test toStringImpl - bool`() {
        assertThat(toStringImpl(false, build.skir.Serializers.bool.impl)).isEqualTo("false")
        assertThat(toStringImpl(true, build.skir.Serializers.bool.impl)).isEqualTo("true")
    }

    @Test
    fun `test toStringImpl - timestamp`() {
        assertThat(
            toStringImpl(Instant.ofEpochMilli(123456789L), build.skir.Serializers.timestamp.impl),
        ).isEqualTo(
            "Instant.ofEpochMillis(\n" +
                "  // 1970-01-02T10:17:36.789Z\n" +
                "  123456789L\n" +
                ")",
        )
    }

    @Test
    fun `test toStringImpl - string`() {
        assertThat(toStringImpl("", build.skir.Serializers.string.impl)).isEqualTo("\"\"")
        assertThat(toStringImpl("foo", build.skir.Serializers.string.impl)).isEqualTo("\"foo\"")
        assertThat(toStringImpl("foo\n", build.skir.Serializers.string.impl)).isEqualTo("\"foo\\n\"")
        assertThat(toStringImpl("foo\nbar", build.skir.Serializers.string.impl)).isEqualTo("\"foo\\n\" +\n  \"bar\"")
        assertThat(toStringImpl("\t\r\"\$", build.skir.Serializers.string.impl)).isEqualTo("\"\\t\\r\\\"\\\$\"")
        assertThat(toStringImpl("\u0001", build.skir.Serializers.string.impl)).isEqualTo("\"\\u0001\"")
    }

    @Test
    fun `test toStringImpl - bytes`() {
        assertThat(toStringImpl(okio.ByteString.EMPTY, build.skir.Serializers.bytes.impl)).isEqualTo("\"\".decodeHex()")
        assertThat(
            toStringImpl("abcd".decodeHex(), build.skir.Serializers.bytes.impl),
        ).isEqualTo("\"abcd\".decodeHex()")
    }

    @Test
    fun `test toStringImpl - optional`() {
        assertThat(
            toStringImpl(null, build.skir.Serializers.optional(build.skir.Serializers.bool).impl),
        ).isEqualTo("null")
        assertThat(
            toStringImpl(true, build.skir.Serializers.optional(build.skir.Serializers.bool).impl),
        ).isEqualTo("true")
    }

    @Test
    fun `test TypeDescriptor type hierarchy`() {
        when (build.skir.Serializers.bool.typeDescriptor) {
            is PrimitiveDescriptor.Reflective<*> -> {}
            is OptionalDescriptor.Reflective<*> -> {}
            is OptionalDescriptor.JavaReflective<*> -> {}
            is ArrayDescriptor.Reflective<*, *> -> {}
            is RecordDescriptor.Reflective<*, *> -> {}
        }
        when (build.skir.Serializers.bool.typeDescriptor) {
            is PrimitiveDescriptor.Reflective<*> -> {}
            is OptionalDescriptor.Reflective<*> -> {}
            is OptionalDescriptor.JavaReflective<*> -> {}
            is ArrayDescriptor.Reflective<*, *> -> {}
            is StructDescriptor.Reflective<*, *> -> {}
            is EnumDescriptor.Reflective<*> -> {}
        }
        when (parseTypeDescriptorImpl(build.skir.Serializers.bool.typeDescriptor.asJson())) {
            is PrimitiveDescriptor -> {}
            is OptionalDescriptor -> {}
            is OptionalDescriptor.JavaReflective<*> -> {}
            is ArrayDescriptor -> {}
            is RecordDescriptor<*> -> {}
        }
        when (TypeDescriptor.parseFromJsonCode(build.skir.Serializers.bool.typeDescriptor.asJsonCode())) {
            is PrimitiveDescriptor -> {}
            is OptionalDescriptor -> {}
            is ArrayDescriptor -> {}
            is StructDescriptor -> {}
            is EnumDescriptor -> {}
        }
    }
}
