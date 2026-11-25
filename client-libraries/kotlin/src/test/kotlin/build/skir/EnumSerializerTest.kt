package build.skir

import build.skir.internal.EnumSerializer
import build.skir.internal.UnrecognizedVariant
import build.skir.internal.toStringImpl
import build.skir.reflection.parseTypeDescriptorImpl
import com.google.common.truth.Truth.assertThat
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import okio.ByteString
import org.junit.jupiter.api.Test

class EnumSerializerTest {
    // Test enum types
    sealed class Color {
        abstract val kindOrdinal: Int

        data class Unknown(val unrecognized: UnrecognizedVariant<Color>?) : Color() {
            override val kindOrdinal = 0
        }

        object RED : Color() {
            override val kindOrdinal = 1
        }

        object GREEN : Color() {
            override val kindOrdinal = 2
        }

        object BLUE : Color() {
            override val kindOrdinal = 3
        }

        data class CustomOption(val rgb: Int) : Color() {
            override val kindOrdinal = 4
        }

        companion object {
            val UNKNOWN = Unknown(null)
        }
    }

    sealed class Status {
        abstract val kindOrdinal: Int

        data class Unknown(val unrecognized: UnrecognizedVariant<Status>) : Status() {
            override val kindOrdinal = 0
        }

        object ACTIVE : Status() {
            override val kindOrdinal = 1
        }

        object INACTIVE : Status() {
            override val kindOrdinal = 2
        }

        data class PendingOption(val reason: String) : Status() {
            override val kindOrdinal = 3
        }

        data class ErrorOption(val message: String) : Status() {
            override val kindOrdinal = 4
        }
    }

    // Simple enum with only constants
    private val colorEnumSerializer =
        EnumSerializer.create<Color, Color.Unknown>(
            "foo.bar:Color",
            doc = "",
            { it.kindOrdinal },
            5,
            Color.UNKNOWN,
            { unrecognized -> Color.Unknown(unrecognized) },
            { enum -> enum.unrecognized },
        ).apply {
            addConstantVariant(1, "red", 1, "", Color.RED)
            addConstantVariant(2, "green", 2, "", Color.GREEN)
            addConstantVariant(3, "blue", 3, "", Color.BLUE)
            addWrapperVariant(4, "custom", 4, build.skir.Serializers.int32, "", { Color.CustomOption(it) }, { it.rgb })
            finalizeEnum()
        }

    // Complex enum with both constants and wrapper fields
    private val statusEnumSerializer =
        EnumSerializer.create<Status, Status.Unknown>(
            "foo.bar:Color.Status",
            doc = "A status",
            { it.kindOrdinal },
            4,
            Status.Unknown(UnrecognizedVariant(JsonPrimitive(0))),
            { unrecognized -> Status.Unknown(unrecognized) },
            { enum -> enum.unrecognized },
        ).apply {
            addConstantVariant(1, "active", 1, "active status", Status.ACTIVE)
            addConstantVariant(2, "inactive", 2, "", Status.INACTIVE)
            addWrapperVariant(3, "pending", 3, build.skir.Serializers.string, "pending status", {
                Status.PendingOption(it)
            }, { it.reason })
            addRemovedNumber(4) // Removed field number
            finalizeEnum()
        }

    private val colorSerializer = Serializer(colorEnumSerializer)
    private val statusSerializer = Serializer(statusEnumSerializer)

    @Test
    fun `test enum serializer - constant fields dense JSON`() {
        // Test constant field serialization in dense format
        val redJson = colorEnumSerializer.toJson(Color.RED, readableFlavor = false)
        assertThat(redJson).isInstanceOf(JsonPrimitive::class.java)
        assertThat((redJson as JsonPrimitive).content).isEqualTo("1")

        val greenJson = colorEnumSerializer.toJson(Color.GREEN, readableFlavor = false)
        assertThat((greenJson as JsonPrimitive).content).isEqualTo("2")

        val blueJson = colorEnumSerializer.toJson(Color.BLUE, readableFlavor = false)
        assertThat((blueJson as JsonPrimitive).content).isEqualTo("3")

        // Test deserialization from dense format
        assertThat(colorEnumSerializer.fromJson(JsonPrimitive(1), keepUnrecognizedValues = false)).isEqualTo(Color.RED)
        assertThat(
            colorEnumSerializer.fromJson(JsonPrimitive(2), keepUnrecognizedValues = false),
        ).isEqualTo(Color.GREEN)
        assertThat(colorEnumSerializer.fromJson(JsonPrimitive(3), keepUnrecognizedValues = false)).isEqualTo(Color.BLUE)
    }

    @Test
    fun `test enum serializer - constant fields readable JSON`() {
        // Test constant field serialization in readable format
        val redJson = colorEnumSerializer.toJson(Color.RED, readableFlavor = true)
        assertThat(redJson).isInstanceOf(JsonPrimitive::class.java)
        assertThat((redJson as JsonPrimitive).content).isEqualTo("red")

        val greenJson = colorEnumSerializer.toJson(Color.GREEN, readableFlavor = true)
        assertThat((greenJson as JsonPrimitive).content).isEqualTo("green")

        val blueJson = colorEnumSerializer.toJson(Color.BLUE, readableFlavor = true)
        assertThat((blueJson as JsonPrimitive).content).isEqualTo("blue")

        // Test deserialization from readable format
        assertThat(
            colorEnumSerializer.fromJson(JsonPrimitive("red"), keepUnrecognizedValues = false),
        ).isEqualTo(Color.RED)
        assertThat(
            colorEnumSerializer.fromJson(JsonPrimitive("green"), keepUnrecognizedValues = false),
        ).isEqualTo(Color.GREEN)
        assertThat(
            colorEnumSerializer.fromJson(JsonPrimitive("blue"), keepUnrecognizedValues = false),
        ).isEqualTo(Color.BLUE)
    }

    @Test
    fun `test enum serializer - wrapper fields dense JSON`() {
        val customColor = Color.CustomOption(0xFF0000)

        // Test wrapper field serialization in dense format
        val customJson = colorEnumSerializer.toJson(customColor, readableFlavor = false)
        assertThat(customJson).isInstanceOf(JsonArray::class.java)

        val jsonArray = customJson as JsonArray
        assertThat(jsonArray).hasSize(2)
        assertThat((jsonArray[0] as JsonPrimitive).content).isEqualTo("4")
        assertThat((jsonArray[1] as JsonPrimitive).content).isEqualTo("16711680")

        // Test deserialization from dense format
        val restored = colorEnumSerializer.fromJson(jsonArray, keepUnrecognizedValues = false)
        assertThat(restored).isInstanceOf(Color.CustomOption::class.java)
        assertThat((restored as Color.CustomOption).rgb).isEqualTo(0xFF0000)
    }

    @Test
    fun `test enum serializer - wrapper fields readable JSON`() {
        val customColor = Color.CustomOption(0x00FF00)

        // Test wrapper field serialization in readable format
        val customJson = colorEnumSerializer.toJson(customColor, readableFlavor = true)
        assertThat(customJson).isInstanceOf(JsonObject::class.java)

        val jsonObject = customJson as JsonObject
        assertThat(jsonObject).hasSize(2)
        assertThat(jsonObject).containsKey("kind")
        assertThat(jsonObject).containsKey("value")
        assertThat((jsonObject["kind"] as JsonPrimitive).content).isEqualTo("custom")
        assertThat((jsonObject["value"] as JsonPrimitive).content).isEqualTo("65280")

        // Test deserialization from readable format
        val restored = colorEnumSerializer.fromJson(jsonObject, keepUnrecognizedValues = false)
        assertThat(restored).isInstanceOf(Color.CustomOption::class.java)
        assertThat((restored as Color.CustomOption).rgb).isEqualTo(0x00FF00)
    }

    @Test
    fun `test enum serializer - binary format constants`() {
        // Test binary encoding for constant fields
        val redBytes = colorSerializer.toBytes(Color.RED)
        assertThat(redBytes.hex()).startsWith("736b6972")
        // Red should encode as field number 1

        val greenBytes = colorSerializer.toBytes(Color.GREEN)
        assertThat(greenBytes.hex()).startsWith("736b6972")
        // Green should encode as field number 2

        val blueBytes = colorSerializer.toBytes(Color.BLUE)
        assertThat(blueBytes.hex()).startsWith("736b6972")
        // Blue should encode as field number 3

        // Test binary roundtrips
        assertThat(colorSerializer.fromBytes(redBytes.toByteArray())).isEqualTo(Color.RED)
        assertThat(colorSerializer.fromBytes(greenBytes.toByteArray())).isEqualTo(Color.GREEN)
        assertThat(colorSerializer.fromBytes(blueBytes.toByteArray())).isEqualTo(Color.BLUE)
    }

    @Test
    fun `test enum serializer - binary format wrapper fields`() {
        val customColor = Color.CustomOption(42)

        // Test binary encoding for wrapper fields
        val customBytes = colorSerializer.toBytes(customColor)
        assertThat(customBytes.hex()).startsWith("736b6972")

        // Test binary roundtrip
        val restored = colorSerializer.fromBytes(customBytes.toByteArray())
        assertThat(restored).isInstanceOf(Color.CustomOption::class.java)
        assertThat((restored as Color.CustomOption).rgb).isEqualTo(42)
    }

    @Test
    fun `test enum serializer - default detection`() {
        // Test isDefault
        assertThat(colorEnumSerializer.isDefault(Color.UNKNOWN)).isTrue()
        assertThat(colorEnumSerializer.isDefault(Color.Unknown(UnrecognizedVariant(JsonPrimitive(0))))).isFalse()
        assertThat(colorEnumSerializer.isDefault(Color.RED)).isFalse()
        assertThat(colorEnumSerializer.isDefault(Color.CustomOption(123))).isFalse()
    }

    @Test
    fun `test enum serializer - unknown values without keeping unrecognized`() {
        // Test unknown constant number
        val unknownConstant = colorEnumSerializer.fromJson(JsonPrimitive(99), keepUnrecognizedValues = false)
        assertThat(unknownConstant).isInstanceOf(Color.Unknown::class.java)

        // Test unknown field name
        val unknownName = colorEnumSerializer.fromJson(JsonPrimitive("purple"), keepUnrecognizedValues = false)
        assertThat(unknownName).isInstanceOf(Color.Unknown::class.java)

        // Test unknown wrapper field
        val unknownValue =
            colorEnumSerializer.fromJson(
                JsonArray(listOf(JsonPrimitive(99), JsonPrimitive(123))),
                keepUnrecognizedValues = false,
            )
        assertThat(unknownValue).isInstanceOf(Color.Unknown::class.java)
    }

    @Test
    fun `test enum serializer - unknown values with keep unrecognized - JSON`() {
        // Test unknown constant number with keepUnrecognizedValues = true
        val unknownConstant = colorEnumSerializer.fromJson(JsonPrimitive(99), keepUnrecognizedValues = true)
        assertThat(unknownConstant).isInstanceOf(Color.Unknown::class.java)
        val unknownEnum = (unknownConstant as Color.Unknown).unrecognized
        assertThat(unknownEnum?.jsonElement).isEqualTo(JsonPrimitive(99))

        // Test unknown wrapper field with keepUnrecognizedValues = true
        val unknownValueJson = JsonArray(listOf(JsonPrimitive(99), JsonPrimitive(123)))
        val unknownValue = colorEnumSerializer.fromJson(unknownValueJson, keepUnrecognizedValues = true)
        assertThat(unknownValue).isInstanceOf(Color.Unknown::class.java)
        val unknownValueEnum = (unknownValue as Color.Unknown).unrecognized
        assertThat(unknownValueEnum?.jsonElement).isEqualTo(unknownValueJson)
    }

    @Test
    fun `test enum serializer - unknown values with keep unrecognized - binary`() {
        // Test unknown constant number with keepUnrecognizedValues = true
        val serializer = Serializer(colorEnumSerializer)
        val unknownConstant = serializer.fromBytes(byteArrayOf(115, 107, 105, 114, 10), UnrecognizedValuesPolicy.KEEP)
        assertThat(unknownConstant).isInstanceOf(Color.Unknown::class.java)
        val unknownEnum = (unknownConstant as Color.Unknown).unrecognized
        assertThat(unknownEnum?.bytes).isEqualTo(ByteString.of(10))

        val unknownValue =
            serializer.fromBytes(
                byteArrayOf(115, 107, 105, 114, -8, 10, 11),
                UnrecognizedValuesPolicy.KEEP,
            )
        assertThat(unknownValue).isInstanceOf(Color.Unknown::class.java)
        val unknownValueEnum = (unknownValue as Color.Unknown).unrecognized
        assertThat(unknownValueEnum?.bytes).isEqualTo(ByteString.of(-8, 10, 11))
    }

    @Test
    fun `test enum serializer - list of enums`() {
        // Test unknown constant number with keepUnrecognizedValues = true
        val serializer = build.skir.Serializers.list(Serializer(colorEnumSerializer))
        val list = listOf(Color.RED, Color.GREEN, Color.CustomOption(100))
        assertThat(
            serializer.fromBytes(
                serializer.toBytes(list).toByteArray(),
            ),
        ).isEqualTo(list)
    }

    @Test
    fun `test enum serializer - removed fields`() {
        // Test accessing a removed field (should return unknown)
        val removedField = statusEnumSerializer.fromJson(JsonPrimitive(4), keepUnrecognizedValues = false)
        assertThat(removedField).isInstanceOf(Status.Unknown::class.java)
    }

    @Test
    fun `test enum serializer - complex enum roundtrips`() {
        val pendingStatus = Status.PendingOption("waiting for approval")

        // Test JSON roundtrips
        val denseJson = statusSerializer.toJsonCode(pendingStatus)
        val readableJson = statusSerializer.toJsonCode(pendingStatus, JsonFlavor.READABLE)

        val restoredFromDense = statusSerializer.fromJsonCode(denseJson)
        val restoredFromReadable = statusSerializer.fromJsonCode(readableJson)

        assertThat(restoredFromDense).isInstanceOf(Status.PendingOption::class.java)
        assertThat((restoredFromDense as Status.PendingOption).reason).isEqualTo("waiting for approval")

        assertThat(restoredFromReadable).isInstanceOf(Status.PendingOption::class.java)
        assertThat((restoredFromReadable as Status.PendingOption).reason).isEqualTo("waiting for approval")

        // Test binary roundtrip
        val bytes = statusSerializer.toBytes(pendingStatus)
        val restoredFromBinary = statusSerializer.fromBytes(bytes.toByteArray())

        assertThat(restoredFromBinary).isInstanceOf(Status.PendingOption::class.java)
        assertThat((restoredFromBinary as Status.PendingOption).reason).isEqualTo("waiting for approval")
    }

    @Test
    fun `test enum serializer - all constant types roundtrip`() {
        val constantValues = listOf(Status.ACTIVE, Status.INACTIVE)

        constantValues.forEach { status ->
            // Test JSON roundtrips
            val denseJson = statusSerializer.toJsonCode(status, JsonFlavor.DENSE)
            val readableJson = statusSerializer.toJsonCode(status, JsonFlavor.READABLE)

            val restoredFromDense = statusSerializer.fromJsonCode(denseJson)
            val restoredFromReadable = statusSerializer.fromJsonCode(readableJson)

            assertThat(restoredFromDense).isEqualTo(status)
            assertThat(restoredFromReadable).isEqualTo(status)

            // Test binary roundtrip
            val bytes = statusSerializer.toBytes(status)
            val restoredFromBinary = statusSerializer.fromBytes(bytes.toByteArray())

            assertThat(restoredFromBinary).isEqualTo(status)
        }
    }

    @Test
    fun `test enum serializer - error cases`() {
        // Test that finalizeEnum() can only be called once
        val testEnumSerializer =
            EnumSerializer.create<Color, Color.Unknown>(
                "foo.bar:Color",
                "",
                { it.kindOrdinal },
                4,
                Color.Unknown(UnrecognizedVariant(JsonPrimitive(0))),
                { unrecognized -> Color.Unknown(unrecognized) },
                { enum -> enum.unrecognized },
            )

        testEnumSerializer.addConstantVariant(1, "test", 1, "", Color.RED)
        testEnumSerializer.finalizeEnum()

        // Adding fields after finalization should throw
        var exceptionThrown = false
        try {
            testEnumSerializer.addConstantVariant(2, "test2", 2, "", Color.GREEN)
        } catch (e: IllegalStateException) {
            exceptionThrown = true
        }
        assertThat(exceptionThrown).isTrue()

        // Double finalization should throw
        exceptionThrown = false
        try {
            testEnumSerializer.finalizeEnum()
        } catch (e: IllegalStateException) {
            exceptionThrown = true
        }
        assertThat(exceptionThrown).isTrue()
    }

    @Test
    fun `test enum serializer - edge cases`() {
        // Test with edge case values
        val edgeCases =
            listOf(
                Color.CustomOption(0),
                Color.CustomOption(Int.MAX_VALUE),
                Color.CustomOption(Int.MIN_VALUE),
            )

        edgeCases.forEach { color ->
            // Test JSON roundtrips
            val denseJson = colorSerializer.toJsonCode(color)
            val readableJson = colorSerializer.toJsonCode(color, JsonFlavor.READABLE)

            val restoredFromDense = colorSerializer.fromJsonCode(denseJson)
            val restoredFromReadable = colorSerializer.fromJsonCode(readableJson)

            assertThat(restoredFromDense).isInstanceOf(Color.CustomOption::class.java)
            assertThat((restoredFromDense as Color.CustomOption).rgb).isEqualTo(color.rgb)

            assertThat(restoredFromReadable).isInstanceOf(Color.CustomOption::class.java)
            assertThat((restoredFromReadable as Color.CustomOption).rgb).isEqualTo(color.rgb)

            // Test binary roundtrip
            val bytes = colorSerializer.toBytes(color)
            val restoredFromBinary = colorSerializer.fromBytes(bytes.toByteArray())

            assertThat(restoredFromBinary).isInstanceOf(Color.CustomOption::class.java)
            assertThat((restoredFromBinary as Color.CustomOption).rgb).isEqualTo(color.rgb)
        }
    }

    @Test
    fun `test enum serializer - json format consistency`() {
        // Test that dense and readable formats are different for wrapper fields but same for constants
        val redConstant = Color.RED
        val customValue = Color.CustomOption(0xABCDEF)

        // Constants should be different between dense/readable
        val redDenseJson = colorSerializer.toJsonCode(redConstant)
        val redReadableJson = colorSerializer.toJsonCode(redConstant, JsonFlavor.READABLE)
        assertThat(redDenseJson).isNotEqualTo(redReadableJson)

        // Wrapper fields should be different between dense/readable
        val customDenseJson = colorSerializer.toJsonCode(customValue)
        val customReadableJson = colorSerializer.toJsonCode(customValue, JsonFlavor.READABLE)
        assertThat(customDenseJson).isNotEqualTo(customReadableJson)

        // Dense should be array/number, readable should be string/object
        assertThat(redDenseJson.toLongOrNull()).isNotNull()
        assertThat(redReadableJson).startsWith("\"")
        assertThat(redReadableJson).endsWith("\"")

        assertThat(customDenseJson).startsWith("[")
        assertThat(customDenseJson).endsWith("]")
        assertThat(customReadableJson).startsWith("{")
        assertThat(customReadableJson).endsWith("}")
    }

    @Test
    fun `test enum serializer - field number ranges`() {
        // Test that field numbers work correctly for different ranges
        // Using the existing colorEnumSerializer which has field numbers 1, 2, 3, 4

        val constantValues = listOf(Color.RED, Color.GREEN, Color.BLUE)
        constantValues.forEach { constant ->
            val bytes = colorSerializer.toBytes(constant)
            val restored = colorSerializer.fromBytes(bytes.toByteArray())
            assertThat(restored).isEqualTo(constant)
        }

        // Test wrapper field
        val customColor = Color.CustomOption(42)
        val bytes = colorSerializer.toBytes(customColor)
        val restored = colorSerializer.fromBytes(bytes.toByteArray())
        assertThat(restored).isInstanceOf(Color.CustomOption::class.java)
        assertThat((restored as Color.CustomOption).rgb).isEqualTo(42)
    }

    @Test
    fun `test enum serializer - multiple value serializers`() {
        // Test with the existing Status enum that already has multiple serializer types
        val testCases =
            listOf(
                Status.ACTIVE,
                Status.INACTIVE,
                Status.PendingOption("waiting for approval"),
            )

        testCases.forEach { testCase ->
            // Test JSON roundtrips
            val denseJson = statusSerializer.toJsonCode(testCase)
            val readableJson = statusSerializer.toJsonCode(testCase, JsonFlavor.READABLE)

            val restoredFromDense = statusSerializer.fromJsonCode(denseJson)
            val restoredFromReadable = statusSerializer.fromJsonCode(readableJson)

            assertThat(restoredFromDense).isEqualTo(testCase)
            assertThat(restoredFromReadable).isEqualTo(testCase)

            // Test binary roundtrip
            val bytes = statusSerializer.toBytes(testCase)
            val restoredFromBinary = statusSerializer.fromBytes(bytes.toByteArray())

            assertThat(restoredFromBinary).isEqualTo(testCase)
        }
    }

    @Test
    fun `test enum serializer - toString()`() {
        assertThat(
            toStringImpl(Status.ACTIVE, statusSerializer.impl),
        ).isEqualTo("EnumSerializerTest.Status.ACTIVE")

        assertThat(
            toStringImpl(Status.PendingOption("foo\nbar"), statusSerializer.impl),
        ).isEqualTo(
            "EnumSerializerTest.Status.PendingOption(\n" +
                "  \"foo\\n\" +\n    \"bar\"\n" +
                ")",
        )
    }

    @Test
    fun `test enum serializer - type descriptor`() {
        val expectedJson =
            "{\n" +
                "  \"type\": {\n" +
                "    \"kind\": \"record\",\n" +
                "    \"value\": \"foo.bar:Color.Status\"\n" +
                "  },\n" +
                "  \"records\": [\n" +
                "    {\n" +
                "      \"kind\": \"enum\",\n" +
                "      \"id\": \"foo.bar:Color.Status\",\n" +
                "      \"doc\": \"A status\",\n" +
                "      \"variants\": [\n" +
                "        {\n" +
                "          \"name\": \"active\",\n" +
                "          \"number\": 1,\n" +
                "          \"doc\": \"active status\"\n" +
                "        },\n" +
                "        {\n" +
                "          \"name\": \"inactive\",\n" +
                "          \"number\": 2\n" +
                "        },\n" +
                "        {\n" +
                "          \"name\": \"pending\",\n" +
                "          \"number\": 3,\n" +
                "          \"type\": {\n" +
                "            \"kind\": \"primitive\",\n" +
                "            \"value\": \"string\"\n" +
                "          },\n" +
                "          \"doc\": \"pending status\"\n" +
                "        }\n" +
                "      ],\n" +
                "      \"removed_numbers\": [\n" +
                "        4\n" +
                "      ]\n" +
                "    }\n" +
                "  ]\n" +
                "}"
        assertThat(
            statusSerializer.typeDescriptor.asJsonCode(),
        ).isEqualTo(
            expectedJson,
        )
        assertThat(
            parseTypeDescriptorImpl(statusSerializer.typeDescriptor.asJson()).asJsonCode(),
        ).isEqualTo(
            expectedJson,
        )
    }

    // =========================================================================
    // Tests for constant variant encoded as wrapper variant (schema migration)
    // =========================================================================

    sealed class MalformedTestEnum {
        abstract val kindOrdinal: Int

        data class Unknown(val unrecognized: UnrecognizedVariant<MalformedTestEnum>?) : MalformedTestEnum() {
            override val kindOrdinal = 0
        }

        // Constant variant
        object ConstantOne : MalformedTestEnum() {
            override val kindOrdinal = 1
        }

        // Normal constant
        object NormalConstant : MalformedTestEnum() {
            override val kindOrdinal = 2
        }

        // Wrapper with default value
        data class WrapperWithDefault(val value: Int) : MalformedTestEnum() {
            override val kindOrdinal = 3
        }

        // Wrapper without default value
        data class WrapperNoDefault(val value: String) : MalformedTestEnum() {
            override val kindOrdinal = 4
        }

        companion object {
            val UNKNOWN = Unknown(null)
        }
    }

    private val malformedTestSerializer =
        EnumSerializer.create<MalformedTestEnum, MalformedTestEnum.Unknown>(
            "test:MalformedTestEnum",
            doc = "Test enum for malformed data handling",
            { it.kindOrdinal },
            5,
            MalformedTestEnum.UNKNOWN,
            { unrecognized -> MalformedTestEnum.Unknown(unrecognized) },
            { enum -> (enum as? MalformedTestEnum.Unknown)?.unrecognized },
        ).apply {
            addConstantVariant(
                number = 1,
                name = "constantOne",
                kindOrdinal = 1,
                doc = "",
                instance = MalformedTestEnum.ConstantOne,
            )
            addConstantVariant(
                number = 2,
                name = "normalConstant",
                kindOrdinal = 2,
                doc = "",
                instance = MalformedTestEnum.NormalConstant,
            )
            addWrapperVariant(
                number = 3,
                name = "wrapperWithDefault",
                kindOrdinal = 3,
                valueSerializer = build.skir.Serializers.int32,
                doc = "",
                wrap = { MalformedTestEnum.WrapperWithDefault(it) },
                getValue = { (it as MalformedTestEnum.WrapperWithDefault).value },
            )
            addWrapperVariant(
                number = 4,
                name = "wrapperNoDefault",
                kindOrdinal = 4,
                valueSerializer = build.skir.Serializers.string,
                doc = "",
                wrap = { MalformedTestEnum.WrapperNoDefault(it) },
                getValue = { (it as MalformedTestEnum.WrapperNoDefault).value },
            )
            finalizeEnum()
        }

    @Test
    fun `test constant variant encoded as wrapper - JSON - returns constant and drops payload`() {
        // When a variant that was once a wrapper is now a constant, the payload is dropped
        val malformedJson = JsonArray(listOf(JsonPrimitive(1), JsonPrimitive("unexpected_value")))
        val resultKeep = malformedTestSerializer.fromJson(malformedJson, keepUnrecognizedValues = true)
        val resultDrop = malformedTestSerializer.fromJson(malformedJson, keepUnrecognizedValues = false)

        assertThat(resultKeep).isEqualTo(MalformedTestEnum.ConstantOne)
        assertThat(resultDrop).isEqualTo(MalformedTestEnum.ConstantOne)
    }

    @Test
    fun `test constant variant encoded as wrapper - binary - returns constant and drops payload`() {
        // Binary format: field #1 encoded as wrapper variant (wire type 251 for field number 1)
        // "skir" header bytes: 115, 107, 105, 114; wire type for wrapper field #1: 251; value: 100
        val serializer = Serializer(malformedTestSerializer)
        val malformedBytes = byteArrayOf(115, 107, 105, 114, 251.toByte(), 100)

        val resultKeep = serializer.fromBytes(malformedBytes, UnrecognizedValuesPolicy.KEEP)
        val resultDrop = serializer.fromBytes(malformedBytes, UnrecognizedValuesPolicy.DROP)

        assertThat(resultKeep).isEqualTo(MalformedTestEnum.ConstantOne)
        assertThat(resultDrop).isEqualTo(MalformedTestEnum.ConstantOne)
    }

    // =========================================================================
    // Tests for wrapper variant encoded as constant (malformed data)
    // =========================================================================

    @Test
    fun `test wrapper variant encoded as constant - JSON - with default value`() {
        // Wrapper variant #3 (has default) encoded as constant (primitive number)
        // Should use the default value
        val malformedJson = JsonPrimitive(3)
        val result = malformedTestSerializer.fromJson(malformedJson, keepUnrecognizedValues = false)

        assertThat(result).isInstanceOf(MalformedTestEnum.WrapperWithDefault::class.java)
        assertThat((result as MalformedTestEnum.WrapperWithDefault).value).isEqualTo(0) // default value
    }

    @Test
    fun `test wrapper variant encoded as constant - JSON by name - with default value`() {
        // Wrapper variant referenced by name instead of number
        val malformedJson = JsonPrimitive("wrapperWithDefault")
        val result = malformedTestSerializer.fromJson(malformedJson, keepUnrecognizedValues = false)

        assertThat(result).isInstanceOf(MalformedTestEnum.WrapperWithDefault::class.java)
        assertThat((result as MalformedTestEnum.WrapperWithDefault).value).isEqualTo(0)
    }

    @Test
    fun `test wrapper variant encoded as constant - binary - with default value`() {
        // Binary format: wrapper field #3 encoded as constant (just the number)
        val serializer = Serializer(malformedTestSerializer)
        // "skir" header, field number (constant encoding)
        val malformedBytes =
            byteArrayOf(
                115,
                107,
                105,
                114,
                3,
            )

        val result = serializer.fromBytes(malformedBytes, UnrecognizedValuesPolicy.DROP)
        assertThat(result).isInstanceOf(MalformedTestEnum.WrapperWithDefault::class.java)
        assertThat((result as MalformedTestEnum.WrapperWithDefault).value).isEqualTo(0)
    }

    // ─── Enum name case-compatibility tests ────────────────────────────────────

    @Test
    fun `serializing lowercase-named constant produces lowercase readable JSON`() {
        // The colorEnumSerializer registers constants as "red", "green", "blue".
        // Readable JSON should use those lowercase names.
        val json = colorEnumSerializer.toJson(Color.RED, readableFlavor = true)
        assertThat((json as JsonPrimitive).content).isEqualTo("red")
    }

    @Test
    fun `parsing UPPER_CASE constant name from readable JSON succeeds`() {
        // Simulate JSON produced by an old serializer that used UPPER_CASE names.
        val result = colorEnumSerializer.fromJson(JsonPrimitive("RED"), keepUnrecognizedValues = false)
        assertThat(result).isEqualTo(Color.RED)
    }

    @Test
    fun `parsing lower_case constant name from readable JSON succeeds`() {
        val result = colorEnumSerializer.fromJson(JsonPrimitive("green"), keepUnrecognizedValues = false)
        assertThat(result).isEqualTo(Color.GREEN)
    }

    @Test
    fun `parsing UPPER_CASE constant name yields same result as lower_case name`() {
        val fromUpper = colorEnumSerializer.fromJson(JsonPrimitive("BLUE"), keepUnrecognizedValues = false)
        val fromLower = colorEnumSerializer.fromJson(JsonPrimitive("blue"), keepUnrecognizedValues = false)
        assertThat(fromUpper).isEqualTo(fromLower)
        assertThat(fromUpper).isEqualTo(Color.BLUE)
    }

    @Test
    fun `parsing UNKNOWN and unknown yield the same unknown variant`() {
        val fromUpper = colorEnumSerializer.fromJson(JsonPrimitive("UNKNOWN"), keepUnrecognizedValues = false)
        val fromLower = colorEnumSerializer.fromJson(JsonPrimitive("unknown"), keepUnrecognizedValues = false)
        assertThat(fromUpper).isEqualTo(fromLower)
        assertThat(fromLower).isEqualTo(Color.UNKNOWN)
    }
}
