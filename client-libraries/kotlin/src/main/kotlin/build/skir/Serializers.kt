package build.skir

import build.skir.internal.INDENT_UNIT
import build.skir.internal.SerializerImpl
import build.skir.internal.decodeNumber
import build.skir.internal.encodeInt32
import build.skir.internal.encodeLengthPrefix
import build.skir.internal.listSerializer
import build.skir.reflection.OptionalDescriptor
import build.skir.reflection.PrimitiveDescriptor
import build.skir.reflection.TypeDescriptor
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.double
import kotlinx.serialization.json.float
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonPrimitive
import okio.Buffer
import okio.BufferedSource
import okio.ByteString
import okio.ByteString.Companion.decodeBase64
import okio.ByteString.Companion.decodeHex
import java.time.Instant
import java.time.format.DateTimeFormatter

/**
 * Provides serializers for all primitive types and utilities for creating composite
 * serializers such as optional and list serializers.
 */
object Serializers {
    /** Serializer for boolean values. */
    @JvmStatic
    @get:JvmName("bool")
    val bool: build.skir.Serializer<Boolean> = build.skir.Serializer(build.skir.BoolSerializer)

    /** Serializer for 32-bit signed integers. */
    @JvmStatic
    @get:JvmName("int32")
    val int32: build.skir.Serializer<Int> = build.skir.Serializer(build.skir.Int32Serializer)

    /** Serializer for 64-bit signed integers. */
    @JvmStatic
    @get:JvmName("int64")
    val int64: build.skir.Serializer<Long> = build.skir.Serializer(build.skir.Int64Serializer)

    /** Serializer for 64-bit unsigned integers. */
    @JvmStatic
    @get:JvmName("hash64")
    val hash64: build.skir.Serializer<ULong> = build.skir.Serializer(build.skir.Hash64Serializer)

    /**
     * Serializer for 64-bit unsigned integers, represented as `long` values on the
     * Java side.
     */
    @JvmStatic
    @get:JvmName("javaHash64")
    val javaHash64: build.skir.Serializer<Long> = build.skir.Serializer(build.skir.JavaHash64Serializer)

    /** Serializer for 32-bit floating-point numbers. */
    @JvmStatic
    @get:JvmName("float32")
    val float32: build.skir.Serializer<Float> = build.skir.Serializer(build.skir.Float32Serializer)

    /** Serializer for 64-bit floating-point numbers. */
    @JvmStatic
    @get:JvmName("float64")
    val float64: build.skir.Serializer<Double> = build.skir.Serializer(build.skir.Float64Serializer)

    /** Serializer for UTF-8 strings. */
    @JvmStatic
    @get:JvmName("string")
    val string: build.skir.Serializer<String> = build.skir.Serializer(build.skir.StringSerializer)

    /** Serializer for byte strings. */
    @JvmStatic
    @get:JvmName("bytes")
    val bytes: build.skir.Serializer<ByteString> = build.skir.Serializer(build.skir.BytesSerializer)

    /** Serializer for timestamp values. */
    @JvmStatic
    @get:JvmName("timestamp")
    val timestamp: build.skir.Serializer<Instant> = build.skir.Serializer(build.skir.TimestampSerializer)

    /**
     * Creates a serializer for nullable values of type [T]?.
     * In Java, prefer using [javaOptional] instead of this method.
     *
     * @param other The serializer for the non-nullable type
     */
    @JvmStatic
    @JvmName("kotlinOptional")
    fun <T : Any> optional(other: build.skir.Serializer<T>): build.skir.Serializer<T?> {
        return build.skir.Serializer(build.skir.OptionalSerializer(other.impl))
    }

    /**
     * Creates a serializer for `java.util.Optional<T>`.
     * In Kotlin, prefer using [optional] instead of this method.
     */
    @JvmStatic
    fun <T : Any> javaOptional(other: build.skir.Serializer<T>): build.skir.Serializer<java.util.Optional<T>> {
        return build.skir.Serializer(build.skir.JavaOptionalSerializer(other.impl))
    }

    /**
     * Creates a serializer for lists of elements of type [E].
     * The lists returned by this serializer are immutable. Any attempt to modify them
     * is guaranteed to throw an exception.
     *
     * @param item The serializer for individual list elements
     */
    @JvmStatic
    fun <E> list(item: build.skir.Serializer<E>): build.skir.Serializer<List<E>> {
        return listSerializer(item)
    }
}

private abstract class PrimitiveSerializer<T> : SerializerImpl<T>() {
    abstract val typeName: String

    override val typeSignature: JsonElement get() =
        JsonObject(
            mapOf(
                "kind" to JsonPrimitive("primitive"),
                "value" to JsonPrimitive(typeName),
            ),
        )
}

private object BoolSerializer : build.skir.PrimitiveSerializer<Boolean>() {
    override fun isDefault(value: Boolean): Boolean {
        return !value
    }

    override fun encode(
        input: Boolean,
        buffer: Buffer,
    ) {
        buffer.writeByte(if (input) 1 else 0)
    }

    override fun decode(
        buffer: BufferedSource,
        keepUnrecognizedValues: Boolean,
    ): Boolean {
        return decodeNumber(buffer).toInt() != 0
    }

    override fun appendString(
        input: Boolean,
        out: StringBuilder,
        eolIndent: String,
    ) {
        out.append(input)
    }

    override fun toJson(
        input: Boolean,
        readableFlavor: Boolean,
    ): JsonElement {
        return if (readableFlavor) {
            JsonPrimitive(input)
        } else {
            JsonPrimitive(if (input) 1 else 0)
        }
    }

    override fun fromJson(
        json: JsonElement,
        keepUnrecognizedValues: Boolean,
    ): Boolean {
        val primitive = json.jsonPrimitive
        return when (primitive.content) {
            "0" -> false
            "0.0" -> false
            "-0.0" -> false
            "false" -> false
            else -> true
        }
    }

    override val typeName get() = "bool"
    override val typeDescriptor get() = PrimitiveDescriptor.Reflective.Bool
}

private object Int32Serializer : build.skir.PrimitiveSerializer<Int>() {
    override fun isDefault(value: Int): Boolean {
        return value == 0
    }

    override fun encode(
        input: Int,
        buffer: Buffer,
    ) {
        encodeInt32(input, buffer)
    }

    override fun decode(
        buffer: BufferedSource,
        keepUnrecognizedValues: Boolean,
    ): Int {
        return decodeNumber(buffer).toInt()
    }

    override fun toJson(
        input: Int,
        readableFlavor: Boolean,
    ): JsonElement {
        return JsonPrimitive(input)
    }

    override fun fromJson(
        json: JsonElement,
        keepUnrecognizedValues: Boolean,
    ): Int {
        val content = json.jsonPrimitive.content
        return try {
            content.toInt()
        } catch (_: NumberFormatException) {
            content.toDouble().toInt()
        }
    }

    override fun appendString(
        input: Int,
        out: StringBuilder,
        eolIndent: String,
    ) {
        out.append(input)
    }

    override val typeName get() = "int32"
    override val typeDescriptor get() = PrimitiveDescriptor.Reflective.Int32
}

private const val MIN_SAFE_JAVASCRIPT_INT = -9007199254740991 // -(2 ^ 53 - 1)
private const val MAX_SAFE_JAVASCRIPT_INT = 9007199254740991 // 2 ^ 53 - 1

private object Int64Serializer : build.skir.PrimitiveSerializer<Long>() {
    override fun isDefault(value: Long): Boolean {
        return value == 0L
    }

    override fun encode(
        input: Long,
        buffer: Buffer,
    ) {
        if (input in -2147483648..2147483647) {
            build.skir.Int32Serializer.encode(input.toInt(), buffer)
        } else {
            buffer.writeByte(238)
            buffer.writeLongLe(input)
        }
    }

    override fun decode(
        buffer: BufferedSource,
        keepUnrecognizedValues: Boolean,
    ): Long {
        return decodeNumber(buffer).toLong()
    }

    override fun toJson(
        input: Long,
        readableFlavor: Boolean,
    ): JsonElement {
        return if (input in build.skir.MIN_SAFE_JAVASCRIPT_INT..build.skir.MAX_SAFE_JAVASCRIPT_INT) {
            JsonPrimitive(input)
        } else {
            JsonPrimitive("$input")
        }
    }

    override fun fromJson(
        json: JsonElement,
        keepUnrecognizedValues: Boolean,
    ): Long {
        val content = json.jsonPrimitive.content
        return try {
            content.toLong()
        } catch (_: NumberFormatException) {
            content.toDouble().toLong()
        }
    }

    override fun appendString(
        input: Long,
        out: StringBuilder,
        eolIndent: String,
    ) {
        out.append(input).append('L')
    }

    override val typeName get() = "int64"
    override val typeDescriptor get() = PrimitiveDescriptor.Reflective.Int64
}

private object Hash64Serializer : build.skir.PrimitiveSerializer<ULong>() {
    override fun isDefault(value: ULong): Boolean {
        return value == 0UL
    }

    override fun encode(
        input: ULong,
        buffer: Buffer,
    ) {
        when {
            input < 232UL -> {
                buffer.writeByte(input.toInt())
            }
            input < 4294967296UL -> {
                if (input < 65536UL) {
                    buffer.writeByte(232)
                    buffer.writeShortLe(input.toInt())
                } else {
                    buffer.writeByte(233)
                    buffer.writeIntLe(input.toInt())
                }
            }
            else -> {
                buffer.writeByte(234)
                buffer.writeLongLe(input.toLong())
            }
        }
    }

    override fun decode(
        buffer: BufferedSource,
        keepUnrecognizedValues: Boolean,
    ): ULong {
        return decodeNumber(buffer).toLong().toULong()
    }

    override fun toJson(
        input: ULong,
        readableFlavor: Boolean,
    ): JsonElement {
        return if (input <= build.skir.MAX_SAFE_JAVASCRIPT_INT.toULong()) {
            JsonPrimitive(input.toLong())
        } else {
            JsonPrimitive("$input")
        }
    }

    override fun fromJson(
        json: JsonElement,
        keepUnrecognizedValues: Boolean,
    ): ULong {
        val content = json.jsonPrimitive.content
        return try {
            content.toULong()
        } catch (_: NumberFormatException) {
            content.toDouble().toULong()
        }
    }

    override fun appendString(
        input: ULong,
        out: StringBuilder,
        eolIndent: String,
    ) {
        out.append(input).append("UL")
    }

    override val typeName get() = "hash64"
    override val typeDescriptor get() = PrimitiveDescriptor.Reflective.Hash64
}

private object JavaHash64Serializer : build.skir.PrimitiveSerializer<Long>() {
    override fun isDefault(value: Long): Boolean {
        return value == 0L
    }

    override fun encode(
        input: Long,
        buffer: Buffer,
    ) {
        return build.skir.Hash64Serializer.encode(input.toULong(), buffer)
    }

    override fun decode(
        buffer: BufferedSource,
        keepUnrecognizedValues: Boolean,
    ): Long {
        return decodeNumber(buffer).toLong()
    }

    override fun toJson(
        input: Long,
        readableFlavor: Boolean,
    ): JsonElement {
        return build.skir.Hash64Serializer.toJson(input.toULong(), readableFlavor)
    }

    override fun fromJson(
        json: JsonElement,
        keepUnrecognizedValues: Boolean,
    ): Long {
        return build.skir.Hash64Serializer.fromJson(json, keepUnrecognizedValues).toLong()
    }

    override fun appendString(
        input: Long,
        out: StringBuilder,
        eolIndent: String,
    ) {
        out.append(input.toULong()).append("UL")
    }

    override val typeName get() = "hash64"
    override val typeDescriptor get() = PrimitiveDescriptor.Reflective.JavaHash64
}

private object Float32Serializer : build.skir.PrimitiveSerializer<Float>() {
    override fun isDefault(value: Float): Boolean {
        return value == 0.0f
    }

    override fun encode(
        input: Float,
        buffer: Buffer,
    ) {
        if (input == 0.0f) {
            buffer.writeByte(0)
        } else {
            buffer.writeByte(240)
            buffer.writeIntLe(input.toBits())
        }
    }

    override fun decode(
        buffer: BufferedSource,
        keepUnrecognizedValues: Boolean,
    ): Float {
        return decodeNumber(buffer).toFloat()
    }

    override fun toJson(
        input: Float,
        readableFlavor: Boolean,
    ): JsonElement {
        return if (input.isFinite()) {
            JsonPrimitive(input)
        } else {
            JsonPrimitive(input.toString())
        }
    }

    override fun fromJson(
        json: JsonElement,
        keepUnrecognizedValues: Boolean,
    ): Float {
        val primitive = json.jsonPrimitive
        return if (primitive.isString) {
            primitive.content.toFloat()
        } else {
            primitive.float
        }
    }

    override fun appendString(
        input: Float,
        out: StringBuilder,
        eolIndent: String,
    ) {
        if (input.isFinite()) {
            out.append(input).append('F')
        } else if (input == Float.NEGATIVE_INFINITY) {
            out.append("Float.NEGATIVE_INFINITY")
        } else if (input == Float.POSITIVE_INFINITY) {
            out.append("Float.POSITIVE_INFINITY")
        } else {
            out.append("Float.NaN")
        }
    }

    override val typeName get() = "float32"
    override val typeDescriptor get() = PrimitiveDescriptor.Reflective.Float32
}

private object Float64Serializer : build.skir.PrimitiveSerializer<Double>() {
    override fun isDefault(value: Double): Boolean {
        return value == 0.0
    }

    override fun encode(
        input: Double,
        buffer: Buffer,
    ) {
        if (input == 0.0) {
            buffer.writeByte(0)
        } else {
            buffer.writeByte(241)
            buffer.writeLongLe(input.toBits())
        }
    }

    override fun decode(
        buffer: BufferedSource,
        keepUnrecognizedValues: Boolean,
    ): Double {
        return decodeNumber(buffer).toDouble()
    }

    override fun toJson(
        input: Double,
        readableFlavor: Boolean,
    ): JsonElement {
        return if (input.isFinite()) {
            JsonPrimitive(input)
        } else {
            JsonPrimitive(input.toString())
        }
    }

    override fun fromJson(
        json: JsonElement,
        keepUnrecognizedValues: Boolean,
    ): Double {
        val primitive = json.jsonPrimitive
        return if (primitive.isString) {
            primitive.content.toDouble()
        } else {
            primitive.double
        }
    }

    override fun appendString(
        input: Double,
        out: StringBuilder,
        eolIndent: String,
    ) {
        if (input.isFinite()) {
            out.append(input)
        } else if (input == Double.NEGATIVE_INFINITY) {
            out.append("Double.NEGATIVE_INFINITY")
        } else if (input == Double.POSITIVE_INFINITY) {
            out.append("Double.POSITIVE_INFINITY")
        } else {
            out.append("Double.NaN")
        }
    }

    override val typeName get() = "float64"
    override val typeDescriptor get() = PrimitiveDescriptor.Reflective.Float64
}

private object StringSerializer : build.skir.PrimitiveSerializer<String>() {
    override fun isDefault(value: String): Boolean {
        return value.isEmpty()
    }

    override fun encode(
        input: String,
        buffer: Buffer,
    ) {
        if (input.isEmpty()) {
            buffer.writeByte(242)
        } else {
            buffer.writeByte(243)
            val bytes = input.toByteArray(Charsets.UTF_8)
            val length = bytes.size
            encodeLengthPrefix(length, buffer)
            buffer.write(bytes)
        }
    }

    override fun decode(
        buffer: BufferedSource,
        keepUnrecognizedValues: Boolean,
    ): String {
        val wire = buffer.readByte().toInt() and 0xFF
        return if (wire == 0 || wire == 242) {
            ""
        } else {
            // Should be wire 243
            val length = decodeNumber(buffer)
            val bytes = buffer.readByteArray(length.toLong())
            String(bytes, Charsets.UTF_8)
        }
    }

    override fun toJson(
        input: String,
        readableFlavor: Boolean,
    ): JsonElement {
        return JsonPrimitive(input)
    }

    override fun fromJson(
        json: JsonElement,
        keepUnrecognizedValues: Boolean,
    ): String {
        val jsonPrimitive = json.jsonPrimitive
        return if (jsonPrimitive.isString) {
            jsonPrimitive.content
        } else if (jsonPrimitive.intOrNull == 0) {
            ""
        } else {
            throw IllegalArgumentException("Expected: string")
        }
    }

    override fun appendString(
        input: String,
        out: StringBuilder,
        eolIndent: String,
    ) {
        // Appends a quoted string which can be copied to a Kotlin source file.
        out.append('"')
        for (i in input.indices) {
            when (val char = input[i]) {
                '\\' -> out.append("\\\\")
                '"' -> out.append("\\\"")
                '\n' -> {
                    out.append("\\n")
                    if (i < input.length - 1) {
                        out.append("\" +${eolIndent}${INDENT_UNIT}\"")
                    }
                }
                '\r' -> out.append("\\r")
                '\t' -> out.append("\\t")
                '\b' -> out.append("\\b")
                '\u000C' -> out.append("\\f")
                '$' -> out.append("\\$")
                else -> {
                    when {
                        // Handle all control characters (0x00-0x1F and 0x7F-0x9F)
                        char.code < 32 || char.code in 127..159 -> {
                            out.append("\\u${char.code.toString(16).padStart(4, '0')}")
                        }
                        // Handle other non-printable Unicode characters
                        !char.isDefined() || char.isISOControl() -> {
                            out.append("\\u${char.code.toString(16).padStart(4, '0')}")
                        }
                        // Regular printable character
                        else -> out.append(char)
                    }
                }
            }
        }
        out.append('"')
    }

    override val typeName get() = "string"
    override val typeDescriptor get() = PrimitiveDescriptor.Reflective.String
}

private object BytesSerializer : build.skir.PrimitiveSerializer<ByteString>() {
    override fun isDefault(value: ByteString): Boolean {
        return value.size == 0
    }

    override fun encode(
        input: ByteString,
        buffer: Buffer,
    ) {
        if (input.size == 0) {
            buffer.writeByte(244)
        } else {
            buffer.writeByte(245)
            val length = input.size
            encodeLengthPrefix(length, buffer)
            buffer.write(input)
        }
    }

    override fun decode(
        buffer: BufferedSource,
        keepUnrecognizedValues: Boolean,
    ): ByteString {
        val wire = buffer.readByte().toInt() and 0xFF
        return if (wire == 0 || wire == 244) {
            ByteString.EMPTY
        } else {
            // Should be wire 245
            val length = decodeNumber(buffer)
            buffer.readByteString(length.toLong())
        }
    }

    override fun appendString(
        input: ByteString,
        out: StringBuilder,
        eolIndent: String,
    ) {
        out.append('"').append(input.hex()).append("\".decodeHex()")
    }

    override fun toJson(
        input: ByteString,
        readableFlavor: Boolean,
    ): JsonElement {
        return if (readableFlavor) {
            JsonPrimitive("hex:${input.hex()}")
        } else {
            JsonPrimitive(input.base64())
        }
    }

    override fun fromJson(
        json: JsonElement,
        keepUnrecognizedValues: Boolean,
    ): ByteString {
        val jsonPrimitive = json.jsonPrimitive
        return if (jsonPrimitive.isString) {
            val content = jsonPrimitive.content
            if (content.startsWith("hex:")) {
                content.substring(4).decodeHex()
            } else {
                content.decodeBase64()!!
            }
        } else if (jsonPrimitive.intOrNull == 0) {
            ByteString.EMPTY
        } else {
            throw IllegalArgumentException("Expected: base64 or hex string")
        }
    }

    override val typeName get() = "bytes"
    override val typeDescriptor get() = PrimitiveDescriptor.Reflective.Bytes
}

private object TimestampSerializer : build.skir.PrimitiveSerializer<Instant>() {
    override fun isDefault(value: Instant): Boolean {
        return value == Instant.EPOCH
    }

    override fun encode(
        input: Instant,
        buffer: Buffer,
    ) {
        val unixMillis = build.skir.TimestampSerializer.clampUnixMillis(input.toEpochMilli())
        if (unixMillis == 0L) {
            buffer.writeByte(0)
        } else {
            buffer.writeByte(239)
            buffer.writeLongLe(unixMillis)
        }
    }

    override fun decode(
        buffer: BufferedSource,
        keepUnrecognizedValues: Boolean,
    ): Instant {
        val unixMillis = build.skir.TimestampSerializer.clampUnixMillis(decodeNumber(buffer).toLong())
        return Instant.ofEpochMilli(unixMillis)
    }

    override fun toJson(
        input: Instant,
        readableFlavor: Boolean,
    ): JsonElement {
        val unixMillis = build.skir.TimestampSerializer.clampUnixMillis(input.toEpochMilli())
        return if (readableFlavor) {
            val clampedInstant = Instant.ofEpochMilli(unixMillis)
            JsonObject(
                mapOf(
                    "unix_millis" to JsonPrimitive(unixMillis),
                    "formatted" to JsonPrimitive(DateTimeFormatter.ISO_INSTANT.format(clampedInstant)),
                ),
            )
        } else {
            JsonPrimitive(unixMillis)
        }
    }

    override fun fromJson(
        json: JsonElement,
        keepUnrecognizedValues: Boolean,
    ): Instant {
        val unixMillisElement = if (json is JsonObject) json["unix_millis"]!! else json
        val unixMillisContent = unixMillisElement.jsonPrimitive.content
        val unixMillis =
            try {
                unixMillisContent.toLong()
            } catch (e: NumberFormatException) {
                unixMillisContent.toDouble().toLong()
            }
        val clampedUnixMillis = build.skir.TimestampSerializer.clampUnixMillis(unixMillis)
        return Instant.ofEpochMilli(clampedUnixMillis)
    }

    override fun appendString(
        input: Instant,
        out: StringBuilder,
        eolIndent: String,
    ) {
        out
            .append("Instant.ofEpochMillis(")
            .append(eolIndent)
            .append(INDENT_UNIT)
            .append("// ")
            .append(DateTimeFormatter.ISO_INSTANT.format(input))
            .append(eolIndent)
            .append(INDENT_UNIT)
            .append(input.toEpochMilli())
            .append("L")
            .append(eolIndent)
            .append(')')
    }

    fun clampUnixMillis(unixMillis: Long): Long {
        return unixMillis.coerceIn(-8640000000000000, 8640000000000000)
    }

    override val typeName get() = "timestamp"
    override val typeDescriptor get() = PrimitiveDescriptor.Reflective.Timestamp
}

private class OptionalSerializer<T : Any>(val other: SerializerImpl<T>) :
    SerializerImpl<T?>(), OptionalDescriptor.Reflective<T> {
    override fun isDefault(value: T?): Boolean {
        return value == null
    }

    override fun encode(
        input: T?,
        buffer: Buffer,
    ) {
        if (input != null) {
            this.other.encode(input, buffer)
        } else {
            buffer.writeByte(255)
        }
    }

    override fun decode(
        buffer: BufferedSource,
        keepUnrecognizedValues: Boolean,
    ): T? {
        return if (buffer.peek().readByte().toInt() and 0xFF == 255) {
            buffer.skip(1)
            null
        } else {
            this.other.decode(buffer, keepUnrecognizedValues = keepUnrecognizedValues)
        }
    }

    override fun appendString(
        input: T?,
        out: StringBuilder,
        eolIndent: String,
    ) {
        if (input == null) {
            out.append("null")
        } else {
            this.other.appendString(input, out, eolIndent)
        }
    }

    override fun toJson(
        input: T?,
        readableFlavor: Boolean,
    ): JsonElement {
        return if (input != null) {
            this.other.toJson(input, readableFlavor = readableFlavor)
        } else {
            JsonNull
        }
    }

    override fun fromJson(
        json: JsonElement,
        keepUnrecognizedValues: Boolean,
    ): T? {
        return if (json is JsonNull) {
            null
        } else {
            this.other.fromJson(json, keepUnrecognizedValues = keepUnrecognizedValues)
        }
    }

    override val otherType: TypeDescriptor.Reflective<T>
        get() = other.typeDescriptor

    override val typeSignature: JsonElement
        get() =
            JsonObject(
                mapOf(
                    "kind" to JsonPrimitive("optional"),
                    "value" to other.typeSignature,
                ),
            )

    override val typeDescriptor get() = this
}

private class JavaOptionalSerializer<T : Any>(val other: SerializerImpl<T>) :
    SerializerImpl<java.util.Optional<T>>(), OptionalDescriptor.JavaReflective<T> {
    override fun isDefault(value: java.util.Optional<T>): Boolean {
        return !value.isPresent
    }

    override fun encode(
        input: java.util.Optional<T>,
        buffer: Buffer,
    ) {
        if (input.isPresent) {
            this.other.encode(input.get(), buffer)
        } else {
            buffer.writeByte(255)
        }
    }

    override fun decode(
        buffer: BufferedSource,
        keepUnrecognizedValues: Boolean,
    ): java.util.Optional<T> {
        return if (buffer.peek().readByte().toInt() and 0xFF == 255) {
            buffer.skip(1)
            java.util.Optional.empty()
        } else {
            java.util.Optional.of(this.other.decode(buffer, keepUnrecognizedValues = keepUnrecognizedValues))
        }
    }

    override fun appendString(
        input: java.util.Optional<T>,
        out: StringBuilder,
        eolIndent: String,
    ) {
        if (input.isPresent) {
            val newEolIndent = eolIndent + INDENT_UNIT
            out.append("Optional.of(").append(newEolIndent)
            this.other.appendString(input.get(), out, newEolIndent)
            out.append(eolIndent).append(")")
        } else {
            out.append("Optional.empty()")
        }
    }

    override fun toJson(
        input: java.util.Optional<T>,
        readableFlavor: Boolean,
    ): JsonElement {
        return if (input.isPresent) {
            this.other.toJson(input.get(), readableFlavor = readableFlavor)
        } else {
            JsonNull
        }
    }

    override fun fromJson(
        json: JsonElement,
        keepUnrecognizedValues: Boolean,
    ): java.util.Optional<T> {
        return if (json is JsonNull) {
            java.util.Optional.empty()
        } else {
            java.util.Optional.of(this.other.fromJson(json, keepUnrecognizedValues = keepUnrecognizedValues))
        }
    }

    override val otherType: TypeDescriptor.Reflective<T>
        get() = other.typeDescriptor

    override val typeSignature: JsonElement
        get() =
            JsonObject(
                mapOf(
                    "kind" to JsonPrimitive("optional"),
                    "value" to other.typeSignature,
                ),
            )

    override val typeDescriptor get() = this
}
