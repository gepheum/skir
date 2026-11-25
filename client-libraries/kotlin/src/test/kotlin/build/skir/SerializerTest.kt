package build.skir

import com.google.common.truth.Truth.assertThat
import okio.ByteString.Companion.decodeHex
import okio.ByteString.Companion.encodeUtf8
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows

class SerializerTest {
    @Test
    fun `deserialization enforces depth limits in JSON and binary formats`() {
        val serializer = Serializers.list(Serializers.list(Serializers.int32))
        val value = listOf(listOf(42))
        val json = serializer.toJsonCode(value)
        val binary = serializer.toBytes(value)
        for (policy in UnrecognizedValuesPolicy.entries) {
            assertThat(serializer.fromJsonCode(json, policy, 2)).isEqualTo(value)
            assertThrows<IllegalArgumentException> { serializer.fromJsonCode(json, policy, 1) }
            for (bytes in listOf(binary, json.encodeUtf8())) {
                assertThat(serializer.fromBytes(bytes, policy, 2)).isEqualTo(value)
                assertThat(serializer.fromBytes(bytes.toByteArray(), policy, 2)).isEqualTo(value)
                assertThrows<IllegalArgumentException> { serializer.fromBytes(bytes, policy, 1) }
                assertThrows<IllegalArgumentException> { serializer.fromBytes(bytes.toByteArray(), policy, 1) }
            }
        }
        assertThat(serializer.fromJsonCode(json, maxNestingDepth = 2)).isEqualTo(value)
        assertThat(serializer.fromBytes(binary, maxNestingDepth = 2)).isEqualTo(value)
        assertThat(serializer.fromBytes(binary.toByteArray(), maxNestingDepth = 2)).isEqualTo(value)
    }

    @Test
    fun `negative depth limits disable checks`() {
        val serializer = Serializers.list(Serializers.int32)
        val value = listOf(42)
        val json = serializer.toJsonCode(value)
        for (maxNestingDepth in listOf(-1, -2)) {
            assertThat(serializer.fromJsonCode(json, maxNestingDepth = maxNestingDepth)).isEqualTo(value)
            for (bytes in listOf(serializer.toBytes(value), json.encodeUtf8())) {
                assertThat(serializer.fromBytes(bytes, maxNestingDepth = maxNestingDepth)).isEqualTo(value)
                assertThat(
                    serializer.fromBytes(bytes.toByteArray(), maxNestingDepth = maxNestingDepth),
                ).isEqualTo(value)
            }
        }
    }

    @Test
    fun `zero depth allows scalars but rejects containers`() {
        assertThat(Serializers.int32.fromJsonCode("42", maxNestingDepth = 0)).isEqualTo(42)
        for (bytes in listOf(Serializers.int32.toBytes(42), "42".encodeUtf8())) {
            assertThat(Serializers.int32.fromBytes(bytes, maxNestingDepth = 0)).isEqualTo(42)
            assertThat(Serializers.int32.fromBytes(bytes.toByteArray(), maxNestingDepth = 0)).isEqualTo(42)
        }
        val serializer = Serializers.list(Serializers.int32)
        assertThrows<IllegalArgumentException> { serializer.fromJsonCode("[]", maxNestingDepth = 0) }
        for (bytes in listOf(serializer.toBytes(emptyList()), "[]".encodeUtf8())) {
            assertThrows<IllegalArgumentException> { serializer.fromBytes(bytes, maxNestingDepth = 0) }
            assertThrows<IllegalArgumentException> { serializer.fromBytes(bytes.toByteArray(), maxNestingDepth = 0) }
        }
    }

    @Test
    fun `fromBytes preserves the entire JSON input`() {
        assertJsonBytes(Serializers.int32, "42", 42)
        assertJsonBytes(Serializers.int32, "-42", -42)
        assertJsonBytes(Serializers.int32, "0", 0)
        assertJsonBytes(Serializers.bool, "true", true)
        assertJsonBytes(Serializers.bool, "false", false)
        assertJsonBytes(Serializers.string, "\"skir\"", "skir")
        assertJsonBytes(Serializers.string, "\"\\u00e9\"", "\u00e9")
        assertJsonBytes(Serializers.optional(Serializers.string), "null", null)
        assertJsonBytes(Serializers.list(Serializers.int32), "[1,2]", listOf(1, 2))
        assertJsonBytes(Serializers.list(Serializers.int32), "[]", emptyList())
        assertJsonBytes(Serializers.int32, " \n42\t", 42)
    }

    @Test
    fun `fromBytes still decodes skir binary input`() {
        val bytes = Serializers.int32.toBytes(42)
        assertThat(Serializers.int32.fromBytes(bytes)).isEqualTo(42)
        assertThat(Serializers.int32.fromBytes(bytes.toByteArray())).isEqualTo(42)
        for (policy in UnrecognizedValuesPolicy.entries) {
            assertThat(Serializers.int32.fromBytes(bytes, policy)).isEqualTo(42)
            assertThat(Serializers.int32.fromBytes(bytes.toByteArray(), policy)).isEqualTo(42)
        }
    }

    @Test
    fun `fromBytes still rejects trailing binary bytes`() {
        val bytes = (Serializers.int32.toBytes(42).hex() + "00").decodeHex()
        assertThrows<IllegalArgumentException> { Serializers.int32.fromBytes(bytes) }
        assertThrows<IllegalArgumentException> { Serializers.int32.fromBytes(bytes.toByteArray()) }
    }

    private fun <T> assertJsonBytes(
        serializer: Serializer<T>,
        jsonCode: String,
        expected: T,
    ) {
        val bytes = jsonCode.encodeUtf8()
        assertThat(serializer.fromBytes(bytes)).isEqualTo(expected)
        assertThat(serializer.fromBytes(bytes.toByteArray())).isEqualTo(expected)
        for (policy in UnrecognizedValuesPolicy.entries) {
            assertThat(serializer.fromBytes(bytes, policy)).isEqualTo(expected)
            assertThat(serializer.fromBytes(bytes.toByteArray(), policy)).isEqualTo(expected)
        }
    }
}
