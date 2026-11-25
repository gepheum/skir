package build.skir.internal

import build.skir.Serializer
import build.skir.reflection.StructDescriptor
import build.skir.reflection.StructField
import build.skir.reflection.TypeDescriptor
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull
import okio.Buffer
import okio.BufferedSource

class StructSerializer<Frozen : Any, Mutable : Any>(
    recordId: String,
    override val doc: String,
    private val defaultInstance: Frozen,
    private val newMutableFn: (Frozen?) -> Mutable,
    private val toFrozenFn: (Mutable) -> Frozen,
    private val getUnrecognizedFields: (Frozen) -> UnrecognizedFields<Frozen>?,
    private val setUnrecognizedFields: (Mutable, UnrecognizedFields<Frozen>) -> Unit,
) : RecordSerializer<Frozen, StructField.Reflective<Frozen, Mutable, *>>(),
    StructDescriptor.Reflective<Frozen, Mutable> {
    override val parsedRecordId = RecordId.parse(recordId)

    private data class Field<Frozen : Any, Mutable : Any, Value>(
        override val name: String,
        val kotlinName: String,
        override val number: Int,
        val serializer: Serializer<Value>,
        override val doc: String,
        val getter: (Frozen) -> Value,
        val setter: (Mutable, Value) -> Unit,
    ) : StructField.Reflective<Frozen, Mutable, Value> {
        fun valueIsDefault(input: Frozen): Boolean {
            return serializer.impl.isDefault(getter(input))
        }

        fun valueToJson(
            input: Frozen,
            readableFlavor: Boolean,
        ): JsonElement {
            return serializer.impl.toJson(getter(input), readableFlavor = readableFlavor)
        }

        fun valueFromJson(
            mutable: Mutable,
            json: JsonElement,
            keepUnrecognizedValues: Boolean,
        ) {
            val value = serializer.impl.fromJson(json, keepUnrecognizedValues = keepUnrecognizedValues)
            setter(mutable, value)
        }

        fun encodeValue(
            input: Frozen,
            buffer: Buffer,
        ) {
            serializer.impl.encode(getter(input), buffer)
        }

        fun decodeValue(
            mutable: Mutable,
            buffer: BufferedSource,
            keepUnrecognizedValues: Boolean,
        ) {
            val value = serializer.impl.decode(buffer, keepUnrecognizedValues = keepUnrecognizedValues)
            setter(mutable, value)
        }

        fun appendString(
            input: Frozen,
            out: StringBuilder,
            eolIndent: String,
        ) {
            serializer.impl.appendString(getter(input), out, eolIndent)
        }

        override val type: TypeDescriptor.Reflective<Value>
            get() = serializer.impl.typeDescriptor

        override fun set(
            struct: Mutable,
            value: Value,
        ) = setter(struct, value)

        override fun get(struct: Frozen) = getter(struct)
    }

    fun <T> addField(
        name: String,
        kotlinName: String,
        number: Int,
        serializer: Serializer<T>,
        doc: String,
        getter: (Frozen) -> T,
        setter: (Mutable, T) -> Unit,
    ) {
        checkNotFinalized()
        val field = Field(name, kotlinName, number, serializer, doc, getter, setter)
        mutableFields.add(field)
        nameToField[field.name] = field
    }

    fun addRemovedNumber(number: Int) {
        checkNotFinalized()
        mutableRemovedNumbers.add(number)
        maxRemovedNumber = maxRemovedNumber.coerceAtLeast(number)
    }

    fun finalizeStruct() {
        checkNotFinalized()
        finalized = true
        mutableFields.sortBy { it.number }
        val slotCountNoRemoved = if (mutableFields.isNotEmpty()) mutableFields.last().number + 1 else 0
        slotCountInclRemoved = (slotCountNoRemoved).coerceAtLeast(maxRemovedNumber + 1)
        slotToField = arrayOfNulls(slotCountInclRemoved)
        for (field in mutableFields) {
            slotToField[field.number] = field
        }
        zeros = List(slotCountInclRemoved) { JSON_ZERO }
    }

    private fun checkNotFinalized() {
        if (finalized) {
            throw IllegalStateException("Struct is already finalized")
        }
    }

    private val mutableFields = mutableListOf<Field<Frozen, Mutable, *>>()
    private val reversedFields = mutableFields.asReversed()
    private val mutableRemovedNumbers = mutableSetOf<Int>()
    private var maxRemovedNumber = -1
    private val nameToField = mutableMapOf<String, Field<Frozen, Mutable, *>>()

    // Includes removed numbers
    private var slotCountInclRemoved = 0

    // Length: `slotCountInclRemoved`
    // Removed numbers are represented as null elements.
    private var slotToField = arrayOf<Field<Frozen, Mutable, *>?>()

    // One zero for each slot
    // Length: `slotCountInclRemoved`
    private var zeros: List<JsonPrimitive> = listOf()
    private var finalized = false

    override fun isDefault(value: Frozen): Boolean {
        return if (value === defaultInstance) {
            true
        } else {
            mutableFields.all {
                it.valueIsDefault(value)
            } && getUnrecognizedFields(value) == null
        }
    }

    override fun toJson(
        input: Frozen,
        readableFlavor: Boolean,
    ): JsonElement {
        return if (readableFlavor) {
            if (input === defaultInstance) {
                EMPTY_JSON_OBJECT
            } else {
                toReadableJson(input)
            }
        } else {
            if (input === defaultInstance) {
                EMPTY_JSON_ARRAY
            } else {
                toDenseJson(input)
            }
        }
    }

    private fun toDenseJson(input: Frozen): JsonArray {
        val unrecognizedFields = getUnrecognizedFields(input)
        return if (unrecognizedFields?.jsonElements != null) {
            // Some unrecognized fields.
            val elements = MutableList(zeros + unrecognizedFields.jsonElements)
            for (field in mutableFields) {
                elements[field.number] = field.valueToJson(input, readableFlavor = false)
            }
            JsonArray(elements)
        } else {
            // No unrecognized fields.
            val slotCount = getSlotCount(input)
            val elements = MutableList<JsonElement>(slotCount) { JSON_ZERO }
            for (i in 0 until slotCount) {
                val field = slotToField[i]
                elements[i] = field?.valueToJson(input, readableFlavor = false) ?: JSON_ZERO
            }
            JsonArray(elements)
        }
    }

    private fun toReadableJson(input: Frozen): JsonObject {
        val nameToElement = mutableMapOf<String, JsonElement>()
        for (field in mutableFields) {
            if (field.valueIsDefault(input)) {
                continue
            }
            nameToElement[field.name] = field.valueToJson(input, readableFlavor = true)
        }
        return JsonObject(nameToElement)
    }

    override fun fromJson(
        json: JsonElement,
        keepUnrecognizedValues: Boolean,
    ): Frozen {
        return if (json is JsonPrimitive && json.intOrNull == 0) {
            defaultInstance
        } else if (json is JsonArray) {
            fromDenseJson(json, keepUnrecognizedValues = keepUnrecognizedValues)
        } else if (json is JsonObject) {
            fromReadableJson(json)
        } else {
            throw IllegalArgumentException("Expected: array or object")
        }
    }

    private fun fromDenseJson(
        jsonArray: JsonArray,
        keepUnrecognizedValues: Boolean,
    ): Frozen {
        val mutable = newMutableFn(null)
        val numSlotsToFill: Int
        if (jsonArray.size > slotCountInclRemoved) {
            // We have some unrecognized fields.
            if (keepUnrecognizedValues) {
                val unrecognizedFields =
                    UnrecognizedFields<Frozen>(
                        jsonArray.size,
                        jsonArray.subList(fromIndex = slotCountInclRemoved, toIndex = jsonArray.size)
                            .map { copyJson(it) }.toList(),
                    )
                setUnrecognizedFields(mutable, unrecognizedFields)
            }
            numSlotsToFill = slotCountInclRemoved
        } else {
            numSlotsToFill = jsonArray.size
        }
        for (field in mutableFields) {
            if (field.number >= numSlotsToFill) {
                break
            }
            field.valueFromJson(mutable, jsonArray[field.number], keepUnrecognizedValues = keepUnrecognizedValues)
        }
        return toFrozen(mutable)
    }

    private fun fromReadableJson(jsonObject: JsonObject): Frozen {
        val mutable = newMutableFn(null)
        for ((name, element) in jsonObject) {
            nameToField[name]?.valueFromJson(mutable, element, keepUnrecognizedValues = false)
        }
        return toFrozen(mutable)
    }

    override fun encode(
        input: Frozen,
        buffer: Buffer,
    ) {
        // Total number of slots to write. Includes removed and unrecognized fields.
        val totalSlotCount: Int
        val recognizedSlotCount: Int
        val unrecognizedBytes: okio.ByteString?
        val unrecognizedFields = getUnrecognizedFields(input)
        if (unrecognizedFields?.bytes != null) {
            totalSlotCount = unrecognizedFields.totalSlotCount
            recognizedSlotCount = this.slotCountInclRemoved
            unrecognizedBytes = unrecognizedFields.bytes
        } else {
            // No unrecognized fields.
            totalSlotCount = getSlotCount(input)
            recognizedSlotCount = totalSlotCount
            unrecognizedBytes = null
        }

        if (totalSlotCount <= 3) {
            buffer.writeByte(246 + totalSlotCount)
        } else {
            buffer.writeByte(250)
            encodeLengthPrefix(totalSlotCount, buffer)
        }
        for (i in 0 until recognizedSlotCount) {
            val field = slotToField[i]
            if (field != null) {
                field.encodeValue(input, buffer)
            } else {
                // Append '0' if the field was removed.
                buffer.writeByte(0)
            }
        }
        if (unrecognizedBytes != null) {
            // Copy the unrecognized fields.
            buffer.write(unrecognizedBytes)
        }
    }

    override fun decode(
        buffer: BufferedSource,
        keepUnrecognizedValues: Boolean,
    ): Frozen {
        val wire = buffer.readByte().toInt() and 0xFF
        if (wire == 0 || wire == 246) {
            return defaultInstance
        }
        val mutable = newMutableFn(null)
        val encodedSlotCount =
            if (wire == 250) {
                decodeNumber(buffer).toInt()
            } else {
                wire - 246
            }
        // Do not read more slots than the number of recognized slots.
        for (i in 0 until encodedSlotCount.coerceAtMost(slotCountInclRemoved)) {
            val field = slotToField[i]
            if (field != null) {
                field.decodeValue(mutable, buffer, keepUnrecognizedValues = keepUnrecognizedValues)
            } else {
                // The field was removed.
                decodeUnused(buffer)
            }
        }
        if (encodedSlotCount > slotCountInclRemoved) {
            // We have some unrecognized fields.
            if (keepUnrecognizedValues) {
                val peekBuffer = buffer.peek()
                var unrecognizedByteCount = 0L
                for (i in slotCountInclRemoved until encodedSlotCount) {
                    unrecognizedByteCount += decodeUnused(peekBuffer)
                }
                val unrecognizedBytes = buffer.readByteString(unrecognizedByteCount)
                val unrecognizedFields =
                    UnrecognizedFields<Frozen>(
                        encodedSlotCount,
                        unrecognizedBytes,
                    )
                setUnrecognizedFields(mutable, unrecognizedFields)
            } else {
                for (i in slotCountInclRemoved until encodedSlotCount) {
                    decodeUnused(buffer)
                }
            }
        }
        return toFrozen(mutable)
    }

    override fun appendString(
        input: Frozen,
        out: StringBuilder,
        eolIndent: String,
    ) {
        val defaultFieldNumbers = mutableSetOf<Int>()
        for (field in mutableFields) {
            if (field.valueIsDefault(input)) {
                defaultFieldNumbers.add(field.number)
            }
        }
        val className = getClassNameWithoutPackage(defaultInstance::class)
        out
            .append(className)
            .append(if (defaultFieldNumbers.isNotEmpty()) ".partial" else "")
            .append('(')
        val newEolIndent = eolIndent + INDENT_UNIT
        for (field in mutableFields) {
            if (defaultFieldNumbers.contains(field.number)) {
                continue
            }
            out.append(newEolIndent).append(field.kotlinName).append(" = ")
            field.appendString(input, out, newEolIndent)
            out.append(',')
        }
        if (defaultFieldNumbers.size < mutableFields.size) {
            out.append(eolIndent)
        }
        out.append(')')
    }

    /**
     * Returns the length of the JSON array for the given input.
     * Assumes that `input` does not contain unrecognized fields.
     */
    private fun getSlotCount(input: Frozen): Int {
        for (field in reversedFields) {
            val isDefault = field.valueIsDefault(input)
            if (!isDefault) {
                return field.number + 1
            }
        }
        return 0
    }

    // =========================================================================
    // REFLECTION: BEGIN
    // =========================================================================

    override val fields: List<StructField.Reflective<Frozen, Mutable, *>> get() =
        java.util.Collections.unmodifiableList(mutableFields)

    override val removedNumbers: Set<Int> get() = java.util.Collections.unmodifiableSet(mutableRemovedNumbers)

    override fun getField(name: String): StructField.Reflective<Frozen, Mutable, *>? {
        return nameToField[name]
    }

    override fun getField(number: Int): StructField.Reflective<Frozen, Mutable, *>? {
        return if (number < slotToField.size) slotToField[number] else null
    }

    override fun newMutable(initializer: Frozen?) = newMutableFn(initializer)

    override fun toFrozen(mutable: Mutable) = toFrozenFn(mutable)

    public override val typeDescriptor: StructDescriptor.Reflective<Frozen, Mutable> get() = this

    // =========================================================================
    // REFLECTION: END
    // =========================================================================

    private companion object {
        val EMPTY_JSON_ARRAY = JsonArray(emptyList())
        val EMPTY_JSON_OBJECT = JsonObject(emptyMap())
        val JSON_ZERO = JsonPrimitive(0)

        fun copyJson(input: JsonElement): JsonElement {
            return when (input) {
                is JsonArray -> {
                    JsonArray(input.map { copyJson(it) }.toList())
                }
                is JsonObject -> {
                    JsonObject(input.mapValues { copyJson(it.value) }.toMap())
                }
                is JsonPrimitive -> {
                    input
                }
            }
        }
    }
}
