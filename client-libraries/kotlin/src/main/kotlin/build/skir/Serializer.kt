package build.skir

import build.skir.internal.SerializerImpl
import build.skir.internal.expectDepthWithinLimit
import build.skir.internal.formatDenseJson
import build.skir.internal.formatReadableJson
import build.skir.reflection.TypeDescriptor
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import okio.Buffer
import okio.ByteString
import okio.ByteString.Companion.encodeUtf8

/** When serializing a value to JSON, you can choose one of two flavors. */
enum class JsonFlavor {
    /**
     * Structs are serialized as JSON arrays, where the field numbers in the index
     * definition match the indexes in the array. Enum constants are serialized as
     * numbers.
     * This is the serialization format you should choose in most cases.
     * It is also the default.
     */
    DENSE,

    /**
     * Structs are serialized as JSON objects, and enum constants are serialized as
     * strings.
     * This format is more verbose and readable, but it should not be used if you need
     * persistence, because skir allows fields to be renamed in record definitions. In
     * other words, never store a readable JSON on disk or in a database.
     */
    READABLE,
}

/**
 * What to do with unrecognized fields when deserializing a value from dense JSON or
 * binary data.
 * Pick [KEEP] if the input JSON or binary string comes from a trusted program which
 * might have been built from more recent source files.
 * Always pick [DROP] if the input JSON or binary string might come from a malicious user.
 */
enum class UnrecognizedValuesPolicy {
    /**
     * Unrecognized fields found when deserializing a value are dropped.
     * Pick this option if the input JSON or binary string might come from a malicious
     * user.
     */
    DROP,

    /**
     * Unrecognized fields found when deserializing a value from dense JSON or binary
     * data are saved.
     * If the value is later re-serialized in the same format (dense JSON or binary),
     * the unrecognized fields will be present in the serialized form.
     */
    KEEP,
}

/**
 * Converts objects of type [T] to and from JSON or binary format.
 *
 * @param T The type of objects this serializer can handle
 * @property typeDescriptor
 */
class Serializer<T> internal constructor(
    internal val impl: SerializerImpl<T>,
) {
    /**
     * Converts an object to its stringified JSON representation.
     * Uses dense JSON flavor.
     *
     * @param input The object to serialize
     * @return The stringified dense JSON representation
     */
    fun toJsonCode(input: T): String {
        return toJsonCode(input, JsonFlavor.DENSE)
    }

    /**
     * Converts an object to its stringified JSON representation.
     *
     * @param input The object to serialize
     * @param flavor Whether to use dense (default) or readable flavor
     * @return The stringified JSON representation
     */
    fun toJsonCode(
        input: T,
        flavor: JsonFlavor,
    ): String {
        val readableFlavor = flavor == JsonFlavor.READABLE
        val jsonElement = this.impl.toJson(input, readableFlavor = readableFlavor)
        return if (readableFlavor) {
            formatReadableJson(jsonElement)
        } else {
            formatDenseJson(jsonElement)
        }
    }

    /**
     * Converts an object to its JSON representation.
     * Uses dense JSON flavor.
     * If you just need the stringified JSON, call [toJsonCode] instead.
     *
     * @param input The object to serialize
     * @return The JSON representation as a JsonElement
     */
    fun toJson(input: T): JsonElement {
        return toJson(input, JsonFlavor.DENSE)
    }

    /**
     * Converts an object to its JSON representation.
     * If you just need the stringified JSON, call [toJsonCode] instead.
     *
     * @param input The object to serialize
     * @param flavor Whether to use dense (default) or readable flavor
     * @return The JSON representation as a JsonElement
     */
    fun toJson(
        input: T,
        flavor: JsonFlavor,
    ): JsonElement {
        return this.impl.toJson(input, readableFlavor = flavor == JsonFlavor.READABLE)
    }

    /**
     * Deserializes an object from its JSON representation.
     * Works with both dense and readable JSON flavors.
     *
     * @param jsonCode The stringified JSON to deserialize
     * @param unrecognizedValues Whether to keep or drop unrecognized fields and variants;
     *     defaults to [UnrecognizedValuesPolicy.DROP]
     * @param maxNestingDepth Maximum container nesting depth; negative values disable the check (default)
     * @return The deserialized object
     */
    @JvmOverloads
    fun fromJsonCode(
        jsonCode: String,
        unrecognizedValues: UnrecognizedValuesPolicy = UnrecognizedValuesPolicy.DROP,
        maxNestingDepth: Int = -1,
    ): T {
        if (maxNestingDepth >= 0) {
            expectDepthWithinLimit(jsonCode, maxNestingDepth)
        }
        val keepUnrecognizedValues = unrecognizedValues == UnrecognizedValuesPolicy.KEEP
        val jsonElement = Json.Default.decodeFromString(JsonElement.serializer(), jsonCode)
        return this.impl.fromJson(jsonElement, keepUnrecognizedValues = keepUnrecognizedValues)
    }

    /**
     * Deserializes an object from its JSON representation.
     * Works with both dense and readable JSON flavors.
     *
     * @param json The JSON element to deserialize
     * @param unrecognizedValues Whether to keep or drop unrecognized fields and variants;
     *     defaults to [UnrecognizedValuesPolicy.DROP]
     * @return The deserialized object
     */
    @JvmOverloads
    fun fromJson(
        json: JsonElement,
        unrecognizedValues: UnrecognizedValuesPolicy = UnrecognizedValuesPolicy.DROP,
    ): T {
        val keepUnrecognizedValues = unrecognizedValues == UnrecognizedValuesPolicy.KEEP
        return this.impl.fromJson(json, keepUnrecognizedValues = keepUnrecognizedValues)
    }

    /**
     * Converts an object to its binary representation.
     *
     * @param input The object to serialize
     * @return The binary representation as a ByteString
     */
    fun toBytes(input: T): ByteString {
        val buffer = Buffer()
        buffer.writeUtf8("skir")
        this.impl.encode(input, buffer)
        return buffer.readByteString()
    }

    /**
     * Deserializes an object from its binary or UTF-8 JSON representation.
     *
     * @param bytes The byte array containing the serialized data
     * @param unrecognizedValues Whether to keep or drop unrecognized fields and variants;
     *     defaults to [UnrecognizedValuesPolicy.DROP]
     * @param maxNestingDepth Maximum nesting depth; negative values disable the check (default)
     * @return The deserialized object
     */
    @JvmOverloads
    fun fromBytes(
        bytes: ByteArray,
        unrecognizedValues: UnrecognizedValuesPolicy = UnrecognizedValuesPolicy.DROP,
        maxNestingDepth: Int = -1,
    ): T {
        val buffer = Buffer()
        buffer.write(bytes)
        return this.fromBytes(buffer, unrecognizedValues, maxNestingDepth)
    }

    /**
     * Deserializes an object from its binary or UTF-8 JSON representation.
     *
     * @param bytes The byte string containing the serialized data
     * @param unrecognizedValues Whether to keep or drop unrecognized fields and variants;
     *     defaults to [UnrecognizedValuesPolicy.DROP]
     * @param maxNestingDepth Maximum nesting depth; negative values disable the check (default)
     * @return The deserialized object
     */
    @JvmOverloads
    fun fromBytes(
        bytes: ByteString,
        unrecognizedValues: UnrecognizedValuesPolicy = UnrecognizedValuesPolicy.DROP,
        maxNestingDepth: Int = -1,
    ): T {
        val buffer = Buffer()
        buffer.write(bytes)
        return this.fromBytes(buffer, unrecognizedValues, maxNestingDepth)
    }

    private fun fromBytes(
        buffer: Buffer,
        unrecognizedValues: UnrecognizedValuesPolicy,
        maxNestingDepth: Int,
    ): T {
        return if (buffer.rangeEquals(0, BINARY_PREFIX)) {
            buffer.skip(4)
            if (maxNestingDepth >= 0) {
                expectDepthWithinLimit(buffer, maxNestingDepth)
            }
            val keepUnrecognizedValues = unrecognizedValues == UnrecognizedValuesPolicy.KEEP
            val result = this.impl.decode(buffer, keepUnrecognizedValues = keepUnrecognizedValues)
            if (!buffer.exhausted()) {
                throw IllegalArgumentException("Extra bytes after deserialization")
            }
            result
        } else {
            this.fromJsonCode(buffer.readUtf8(), unrecognizedValues, maxNestingDepth)
        }
    }

    /**
     * The type descriptor that describes [T].
     * Provides reflective information about the type. For structs and enums, it
     * includes field names types, and other metadata useful for introspection and
     * tooling.
     */
    @get:JvmName("typeDescriptor")
    val typeDescriptor: TypeDescriptor.Reflective<T> = impl.typeDescriptor
}

private val BINARY_PREFIX = "skir".encodeUtf8()
