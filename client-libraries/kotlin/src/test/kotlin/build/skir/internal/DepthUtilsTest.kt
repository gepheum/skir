package build.skir.internal

import build.skir.Serializers
import com.google.common.truth.Truth.assertThat
import okio.Buffer
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows

class DepthUtilsTest {
    @Test
    fun `JSON depth counts containers rather than scalar values`() {
        for (json in listOf("0", "true", "null", "\"text\"")) {
            expectDepthWithinLimit(json, 0)
        }
        for (json in listOf("[]", "{}", "[0]", "{\"key\":0}", "[0,1,2]")) {
            expectDepthWithinLimit(json, 1)
            assertThrows<IllegalArgumentException> { expectDepthWithinLimit(json, 0) }
        }
        for (json in listOf("[[0]]", "{\"key\":[]}", "[{},[]]")) {
            expectDepthWithinLimit(json, 2)
            assertThrows<IllegalArgumentException> { expectDepthWithinLimit(json, 1) }
        }
    }

    @Test
    fun `JSON strings ignore delimiters and handle escaped quotes and backslashes`() {
        val value = "[{]}\"\\\"\\\\"
        expectDepthWithinLimit(Serializers.string.toJsonCode(value), 0)
        expectDepthWithinLimit(Serializers.list(Serializers.string).toJsonCode(listOf(value)), 1)
        expectDepthWithinLimit("{\"[\\\"{\":0}", 1)
        assertThrows<IllegalArgumentException> {
            expectDepthWithinLimit("[${Serializers.string.toJsonCode(value)},[]]", 1)
        }
    }

    @Test
    fun `binary buffer starts at the value and remains unchanged`() {
        val buffer = Buffer().writeByte(247).writeByte(0)
        val original = buffer.snapshot()
        expectDepthWithinLimit(buffer, 1)
        assertThrows<IllegalArgumentException> { expectDepthWithinLimit(buffer, 0) }
        assertThat(buffer.snapshot()).isEqualTo(original)
    }

    @Test
    fun `binary depth counts arrays including empty arrays`() {
        val scalar = Buffer().write(Serializers.int32.toBytes(42))
        scalar.skip(4)
        expectDepthWithinLimit(scalar, 0)
        for (values in listOf(emptyList(), listOf(0), listOf(0, 1), listOf(0, 1, 2), listOf(0, 1, 2, 3))) {
            val buffer = Buffer().write(Serializers.list(Serializers.int32).toBytes(values))
            buffer.skip(4)
            val original = buffer.snapshot()
            expectDepthWithinLimit(buffer, 1)
            assertThrows<IllegalArgumentException> { expectDepthWithinLimit(buffer, 0) }
            assertThat(buffer.snapshot()).isEqualTo(original)
        }
        val nested = Serializers.list(Serializers.list(Serializers.int32))
        for (values in listOf(listOf(emptyList()), listOf(listOf(0)))) {
            val buffer = Buffer().write(nested.toBytes(values))
            buffer.skip(4)
            expectDepthWithinLimit(buffer, 2)
            assertThrows<IllegalArgumentException> { expectDepthWithinLimit(buffer, 1) }
        }
    }

    @Test
    fun `binary skips scalar payloads rather than interpreting them as nesting`() {
        val payloads =
            listOf(
                Serializers.int32.toBytes(-1),
                Serializers.int32.toBytes(-1000),
                Serializers.int32.toBytes(Int.MIN_VALUE),
                Serializers.int32.toBytes(1000),
                Serializers.int32.toBytes(Int.MAX_VALUE),
                Serializers.int64.toBytes(Long.MIN_VALUE),
                Serializers.hash64.toBytes(ULong.MAX_VALUE),
                Serializers.float32.toBytes(1.5f),
                Serializers.float64.toBytes(1.5),
                Serializers.string.toBytes("[[[{"),
                Serializers.bytes.toBytes(Buffer().writeByte(247).writeByte(250).readByteString()),
            )
        for (payload in payloads) {
            val buffer = Buffer().write(payload)
            buffer.skip(4)
            expectDepthWithinLimit(buffer, 0)
        }
    }

    @Test
    fun `binary enum wrappers add nesting levels`() {
        for (wire in 251..254) {
            val buffer = Buffer().writeByte(wire).writeByte(247).writeByte(0)
            expectDepthWithinLimit(buffer, 2)
            assertThrows<IllegalArgumentException> { expectDepthWithinLimit(buffer, 1) }
        }
    }

    @Test
    fun `depth checks are iterative for deeply nested inputs`() {
        val depth = 10000
        val json = "[".repeat(depth) + "0" + "]".repeat(depth)
        expectDepthWithinLimit(json, depth)
        assertThrows<IllegalArgumentException> { expectDepthWithinLimit(json, depth - 1) }
        val binary = Buffer()
        repeat(depth) { binary.writeByte(247) }
        binary.writeByte(0)
        expectDepthWithinLimit(binary, depth)
        assertThrows<IllegalArgumentException> { expectDepthWithinLimit(binary, depth - 1) }
    }

    @Test
    fun `negative depth limits are rejected`() {
        assertThrows<IllegalArgumentException> { expectDepthWithinLimit("0", -1) }
        assertThrows<IllegalArgumentException> { expectDepthWithinLimit(Buffer().writeByte(0), -1) }
    }
}
