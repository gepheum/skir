package build.skir.reflection

import build.skir.internal.JsonObjectBuilder
import build.skir.internal.RecordId
import build.skir.internal.formatReadableJson
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import okio.ByteString
import java.time.Instant

interface TypeDescriptorBase {
    /**
     * Returns the stringified JSON representation of this type descriptor.
     *
     * @return A pretty-printed JSON string describing the type
     */
    fun asJsonCode(): String

    /**
     * Returns the JSON representation of this type descriptor.
     * If you just need the stringified JSON, call [asJsonCode] instead.
     *
     * @return A JsonObject describing the type
     */
    fun asJson(): JsonElement
}

/** Describes a Skir type. */
sealed interface TypeDescriptor : TypeDescriptorBase {
    override fun asJsonCode(): String {
        return asJsonCodeImpl(this)
    }

    override fun asJson(): JsonElement {
        return asJsonImpl(this)
    }

    companion object {
        /**
         * Parses a type descriptor from its JSON string representation, as returned by
         * [asJsonCode].
         */
        fun parseFromJsonCode(jsonCode: String): TypeDescriptor {
            val jsonElement = Json.Default.decodeFromString(JsonElement.serializer(), jsonCode)
            return parseTypeDescriptorImpl(jsonElement)
        }

        /**
         * Parses a type descriptor from its JSON representation, as returned by
         * [asJson].
         */
        fun parseFromJson(json: JsonElement): TypeDescriptor {
            return parseTypeDescriptorImpl(json)
        }
    }

    /** Adds runtime introspection capabilities to a [TypeDescriptor]. */
    sealed interface Reflective<T> : TypeDescriptorBase {
        override fun asJsonCode(): String {
            return asJsonCodeImpl(notReflective)
        }

        override fun asJson(): JsonElement {
            return asJsonImpl(notReflective)
        }

        /** A non-descriptive descriptor equivalent to this reflective descriptor. */
        val notReflective: TypeDescriptor get() = notReflectiveImpl(this, mutableMapOf())

        /**
         * Accepts a [visitor] to perform operations based on the actual Skir type:
         * struct, enum, optional, etc.
         *
         * See a complete example at
         * https://github.com/gepheum/skir-java-example/blob/main/src/main/java/examples/AllStringsToUpperCase.java
         */
        fun accept(visitor: ReflectiveTypeVisitor<T>) {
            ReflectiveTypeVisitor.acceptImpl(this, visitor)
        }
    }
}

/** Enumeration of all primitive types supported by Skir. */
enum class PrimitiveType {
    /** Boolean true/false values. */
    BOOL,

    /** 32-bit signed integers. */
    INT_32,

    /** 64-bit signed integers. */
    INT_64,

    /** 64-bit unsigned integers. */
    UINT_64,

    /** 32-bit floating-point numbers. */
    FLOAT_32,

    /** 64-bit floating-point numbers. */
    FLOAT_64,

    /** Timestamp values representing instants in time. */
    TIMESTAMP,

    /** UTF-8 encoded text strings. */
    STRING,

    /** Binary data (byte sequences). */
    BYTES,
}

/**
 * Base interface for primitive type descriptors.
 */
interface PrimitiveDescriptorBase : TypeDescriptorBase {
    /** The specific primitive type being described. */
    val primitiveType: PrimitiveType
}

/** Describes a primitive type such as integers, strings, booleans, etc. */
class PrimitiveDescriptor private constructor(
    override val primitiveType: PrimitiveType,
) : PrimitiveDescriptorBase, TypeDescriptor {
    sealed interface Reflective<T> : PrimitiveDescriptorBase, TypeDescriptor.Reflective<T> {
        object Bool : Reflective<Boolean> {
            override val primitiveType: PrimitiveType
                get() = PrimitiveType.BOOL
        }

        object Int32 : Reflective<Int> {
            override val primitiveType: PrimitiveType
                get() = PrimitiveType.INT_32
        }

        object Int64 : Reflective<Long> {
            override val primitiveType: PrimitiveType
                get() = PrimitiveType.INT_64
        }

        object Hash64 : Reflective<ULong> {
            override val primitiveType: PrimitiveType
                get() = PrimitiveType.UINT_64
        }

        object JavaHash64 : Reflective<Long> {
            override val primitiveType: PrimitiveType
                get() = PrimitiveType.UINT_64
        }

        object Float32 : Reflective<Float> {
            override val primitiveType: PrimitiveType
                get() = PrimitiveType.FLOAT_32
        }

        object Float64 : Reflective<Double> {
            override val primitiveType: PrimitiveType
                get() = PrimitiveType.FLOAT_64
        }

        object Timestamp : Reflective<Instant> {
            override val primitiveType: PrimitiveType
                get() = PrimitiveType.TIMESTAMP
        }

        object String : Reflective<kotlin.String> {
            override val primitiveType: PrimitiveType
                get() = PrimitiveType.STRING
        }

        object Bytes : Reflective<ByteString> {
            override val primitiveType: PrimitiveType
                get() = PrimitiveType.BYTES
        }
    }

    companion object {
        private val instances = PrimitiveType.entries.map { PrimitiveDescriptor(it) }.toList()

        internal fun getInstance(primitiveType: PrimitiveType): PrimitiveDescriptor {
            return instances[primitiveType.ordinal]
        }
    }
}

/**
 * Base interface for optional type descriptors.
 *
 * @param OtherType The type descriptor for the wrapped non-optional type
 */
interface OptionalDescriptorBase<OtherType : TypeDescriptorBase> : TypeDescriptorBase {
    /** The type descriptor for the wrapped non-optional type. */
    val otherType: OtherType
}

/**
 * Describes an optional type that can hold either a value of the wrapped type or null.
 */
class OptionalDescriptor internal constructor(
    override val otherType: TypeDescriptor,
) : OptionalDescriptorBase<TypeDescriptor>, TypeDescriptor {
    /**
     * Adds runtime introspection capabilities to an [OptionalDescriptor].
     * The value type on the JVM side is `T?`.
     * Preferred in Kotlin over [OptionalDescriptor.JavaReflective].
     */
    interface Reflective<T : Any> :
        OptionalDescriptorBase<TypeDescriptor.Reflective<T>>, TypeDescriptor.Reflective<T?> {
        /**
         * Transforms the wrapped value if present, preserving null values.
         */
        fun map(
            input: T?,
            transformer: ReflectiveTransformer,
        ): T? {
            return if (input == null) {
                null
            } else {
                transformer.transform(input, otherType)
            }
        }
    }

    /**
     * Adds runtime introspection capabilities to an [OptionalDescriptor].
     * The value type on the JVM side is `java.util.Optional<T>`.
     * Preferred in Java over [OptionalDescriptor.Reflective].
     */
    interface JavaReflective<T : Any> :
        OptionalDescriptorBase<TypeDescriptor.Reflective<T>>,
        TypeDescriptor.Reflective<java.util.Optional<T>> {
        /**
         * Transforms the wrapped value if present, preserving empty optionals.
         */
        fun map(
            input: java.util.Optional<T>,
            transformer: ReflectiveTransformer,
        ): java.util.Optional<T> {
            return if (input.isPresent) {
                java.util.Optional.of(transformer.transform(input.get(), otherType))
            } else {
                input
            }
        }
    }
}

interface ArrayDescriptorBase<ItemType : TypeDescriptorBase> : TypeDescriptorBase {
    /** Describes the type of the array items. */
    val itemType: ItemType

    /** Optional key chain for keyed arrays that support fast lookup by key. */
    val keyProperty: String?
}

/**
 * Describes an array type containing elements of a specific type.
 */
class ArrayDescriptor internal constructor(
    override val itemType: TypeDescriptor,
    override val keyProperty: String?,
) : ArrayDescriptorBase<TypeDescriptor>, TypeDescriptor {
    /** Adds runtime introspection capabilities to a [ArrayDescriptor]. */
    interface Reflective<E, L : List<E>> :
        ArrayDescriptorBase<TypeDescriptor.Reflective<E>>, TypeDescriptor.Reflective<L> {
        /** Converts the given list to the specific list type L. */
        fun toList(list: List<E>): L

        /**
         * Transforms each element in the collection using [transformer].
         * Returns a new list containing the transformed elements.
         * Preserves object identity if no elements changed.
         */
        fun map(
            collection: L,
            transformer: ReflectiveTransformer,
        ): L {
            return toList(
                collection.map { element ->
                    transformer.transform(element, itemType)
                },
            )
        }
    }
}

interface FieldOrVariant {
    /** Field name as specified in the '.skir' file, for example "user_id" or "MONDAY". */
    val name: String

    /** Field number. */
    val number: Int

    /** Documentation for this field/variant, extracted from doc comments in the '.skir' file. */
    val doc: String
}

interface RecordDescriptorBase : TypeDescriptorBase {
    /** Name of the record as specified in the '.skir' file. */
    val name: String

    /**
     * A string containing all the names in the hierarchic sequence above and
     * including the struct. For example: "Foo.Bar" if "Bar" is nested within a
     * type called "Foo", or simply "Bar" if "Bar" is defined at the top-level of
     * the module.
     */
    val qualifiedName: String

    /** Path to the '.skir' file relative to the root of the skir source directory. */
    val modulePath: String

    /** Documentation for this struct/enum, extracted from doc comments in the '.skir' file. */
    val doc: String

    /** The field numbers marked as removed. */
    val removedNumbers: Set<Int>
}

private fun RecordDescriptorBase.recordId(): String = "${this.modulePath}:${this.qualifiedName}"

/**
 * Describes a record type (struct or enum).
 */
sealed class RecordDescriptor<F : FieldOrVariant> : RecordDescriptorBase, TypeDescriptor {
    /** Adds runtime introspection capabilities to a [RecordDescriptor]. */
    sealed interface Reflective<T, F : FieldOrVariant> : RecordDescriptorBase, TypeDescriptor.Reflective<T>
}

interface StructFieldBase<TypeDescriptor : TypeDescriptorBase> : FieldOrVariant {
    /** Describes the field type. */
    val type: TypeDescriptor
}

/** Describes a field in a struct. */
class StructField internal constructor(
    /** Field name as specified in the '.skir' file, for example "user_id". */
    override val name: String,
    override val number: Int,
    override val type: TypeDescriptor,
    override val doc: String,
) : StructFieldBase<TypeDescriptor> {
    /** Adds runtime introspection capabilities to a [StructField]. */
    interface Reflective<Frozen, Mutable, Value> : StructFieldBase<TypeDescriptor.Reflective<Value>> {
        /** Extracts the value of the field from the given struct. */
        fun get(struct: Frozen): Value

        /** Assigns the given value to the field of the given struct. */
        fun set(
            struct: Mutable,
            value: Value,
        )

        /**
         * Copies this field's value from [source] to [target].
         * If a [transformer] is provided, it is applied to the value before setting it.
         */
        fun copy(
            source: Frozen,
            target: Mutable,
            transformer: ReflectiveTransformer = ReflectiveTransformer.Identity,
        ) {
            set(
                target,
                transformer.transform(
                    get(source),
                    type,
                ),
            )
        }
    }
}

interface StructDescriptorBase<Field : StructFieldBase<*>> : RecordDescriptorBase {
    /** List of all fields in this record. */
    val fields: List<Field>

    /**
     * Looks up a field by name.
     *
     * @param name The field name to search for
     * @return The field with the given name, or null if not found
     */
    fun getField(name: String): Field?

    /**
     * Looks up a field by number.
     *
     * @param number The field number to search for
     * @return The field with the given number, or null if not found
     */
    fun getField(number: Int): Field?
}

/**
 * Describes a Skir struct type with its fields and structure.
 *
 * @property name
 */
class StructDescriptor internal constructor(
    private val recordId: RecordId,
    override val doc: String,
    override val removedNumbers: Set<Int>,
    fields: List<StructField> = listOf(),
) : RecordDescriptor<StructField>(), StructDescriptorBase<StructField> {
    override var fields: List<StructField> = fields
        internal set

    override fun getField(name: String): StructField? {
        return nameToField[name]
    }

    override fun getField(number: Int): StructField? {
        return numberToField[number]
    }

    private val nameToField by lazy {
        fields.associateBy { it.name }
    }

    private val numberToField by lazy {
        fields.associateBy { it.number }
    }

    /** Name of the struct as specified in the '.skir' file. */
    override val name: String get() = recordId.name

    /** Qualified struct name, for example "Foo" or "Foo.Bar" if `Bar` is nested. */
    override val qualifiedName: String get() = recordId.qualifiedName

    /** Path to the '.skir' file relative to the root of the skir source directory. */
    override val modulePath: String get() = recordId.modulePath

    /** Adds runtime introspection capabilities to a [StructDescriptor]. */
    interface Reflective<Frozen, Mutable> :
        StructDescriptorBase<StructField.Reflective<Frozen, Mutable, *>>,
        RecordDescriptor.Reflective<Frozen, StructField.Reflective<Frozen, Mutable, *>> {
        /**
         * Returns a new instance of the generated mutable class for a struct.
         * Performs a shallow copy of `initializer` if `initializer` is specified.
         */
        fun newMutable(initializer: Frozen? = null): Mutable

        /**
         * Converts a mutable struct instance to its frozen (immutable) form.
         */
        fun toFrozen(mutable: Mutable): Frozen

        /**
         * Applies [transformer] to each field value in [struct]. Returns a frozen
         * struct containing the transformed field values.
         * Preserves object identity if no fields changed.
         */
        fun mapFields(
            struct: Frozen,
            transformer: ReflectiveTransformer,
        ): Frozen {
            val mutable = newMutable()
            for (field in fields) {
                field.copy(struct, mutable, transformer)
            }
            return toFrozen(mutable)
        }
    }
}

/** Describes a variant in an enum. Can be either a constant variant or a wrapper variant. */
sealed interface EnumVariant : FieldOrVariant {
    /** Adds runtime introspection capabilities to an [EnumVariant]. */
    sealed interface Reflective<Enum> : FieldOrVariant
}

interface EnumConstantVariantBase : FieldOrVariant

/** Describes an enum constant variant. */
class EnumConstantVariant internal constructor(
    override val name: String,
    override val number: Int,
    override val doc: String,
) : EnumConstantVariantBase, EnumVariant {
    /** Adds runtime introspection capabilities to an [EnumConstantVariant]. */
    interface Reflective<Enum> : EnumConstantVariantBase, EnumVariant.Reflective<Enum> {
        /** The constant value represented by this variant. */
        val constant: Enum
    }
}

interface EnumWrapperVariantBase<TypeDescriptor : TypeDescriptorBase> : FieldOrVariant {
    /** The type of the value associated with this enum variant. */
    val type: TypeDescriptor
}

/** Describes an enum wrapper variant. */
class EnumWrapperVariant internal constructor(
    override val name: String,
    override val number: Int,
    override val type: TypeDescriptor,
    override val doc: String,
) : EnumWrapperVariantBase<TypeDescriptor>, EnumVariant {
    /**
     * Adds runtime introspection capabilities to an [EnumWrapperVariant].
     *
     * @param Enum The enum type
     * @param Value The type of the associated value
     */
    interface Reflective<Enum, Value> :
        EnumWrapperVariantBase<TypeDescriptor.Reflective<Value>>, EnumVariant.Reflective<Enum> {
        /** Returns whether the variant of the given enum instance matches this variant. */
        fun test(e: Enum): Boolean

        /**
         * Extracts the value held by the given enum instance assuming its variant
         * matches this variant. Throws an exception if `test(e)` is false.
         */
        fun get(e: Enum): Value

        /**
         * Returns a new enum instance holding the given value.
         */
        fun wrap(value: Value): Enum

        /**
         * Applies [transformer] to the wrapped value and returns a new enum instance
         * wrapping around it. Throws an exception if `test(e)` is false.
         */
        fun mapValue(
            e: Enum,
            transformer: ReflectiveTransformer,
        ): Enum {
            return wrap(transformer.transform(get(e), type))
        }
    }
}

interface EnumDescriptorBase<Variant : FieldOrVariant> : RecordDescriptorBase {
    /** List of all variants in this record. */
    val variants: List<Variant>

    /**
     * Looks up a variant by name.
     *
     * @param name The variant name to search for
     * @return The variant with the given name, or null if not found
     */
    fun getVariant(name: String): Variant?

    /**
     * Looks up a variant by number.
     *
     * @param number The variant number to search for
     * @return The variant with the given number, or null if not found
     */
    fun getVariant(number: Int): Variant?
}

/** Describes a Skir enum type. */
class EnumDescriptor internal constructor(
    private val recordId: RecordId,
    override val doc: String,
    override val removedNumbers: Set<Int>,
    variants: List<EnumVariant> = listOf(),
) : RecordDescriptor<EnumVariant>(), EnumDescriptorBase<EnumVariant> {
    override var variants: List<EnumVariant> = variants
        internal set

    /** Name of the enum as specified in the '.skir' file. */
    override val name: String get() = recordId.name

    /** Qualified enum name, for example "Foo" or "Foo.Bar" if `Bar` is nested. */
    override val qualifiedName: String get() = recordId.qualifiedName

    /** Path to the '.skir' file relative to the root of the skir source directory. */
    override val modulePath: String get() = recordId.modulePath

    override fun getVariant(name: String): EnumVariant? {
        return nameToVariant[name]
    }

    override fun getVariant(number: Int): EnumVariant? {
        return numberToVariant[number]
    }

    private val nameToVariant by lazy {
        variants.associateBy { it.name }
    }

    private val numberToVariant by lazy {
        variants.associateBy { it.number }
    }

    /**
     * Adds runtime introspection capabilities to an [EnumDescriptor].
     *
     * @param Enum The enum type
     */
    interface Reflective<Enum> :
        EnumDescriptorBase<EnumVariant.Reflective<Enum>>,
        RecordDescriptor.Reflective<Enum, EnumVariant.Reflective<Enum>> {
        /** Looks up the variant corresponding to the given instance of Enum. */
        fun getVariant(e: Enum): EnumVariant.Reflective<Enum>

        /**
         * If [e] holds a value (wrapper variant), extracts the value, transforms it
         * and returns a new enum instance wrapping around it.
         * Otherwise, returns [e] unchanged.
         */
        fun mapValue(
            e: Enum,
            transformer: ReflectiveTransformer,
        ): Enum {
            val variant = getVariant(e)
            return if (variant is EnumWrapperVariant.Reflective<Enum, *>) {
                variant.mapValue(e, transformer)
            } else {
                e
            }
        }
    }
}

private fun notReflectiveImpl(
    descriptor: TypeDescriptor.Reflective<*>,
    inProgress: MutableMap<TypeDescriptor.Reflective<*>, TypeDescriptor>,
): TypeDescriptor {
    run {
        val inProgressResult = inProgress[descriptor]
        if (inProgressResult != null) {
            return inProgressResult
        }
    }
    return when (descriptor) {
        is PrimitiveDescriptor.Reflective -> PrimitiveDescriptor.getInstance(descriptor.primitiveType)
        is OptionalDescriptor.Reflective<*> ->
            OptionalDescriptor(
                otherType = notReflectiveImpl(descriptor.otherType, inProgress),
            )
        is OptionalDescriptor.JavaReflective<*> ->
            OptionalDescriptor(
                otherType = notReflectiveImpl(descriptor.otherType, inProgress),
            )
        is ArrayDescriptor.Reflective<*, *> ->
            ArrayDescriptor(
                itemType = notReflectiveImpl(descriptor.itemType, inProgress),
                keyProperty = descriptor.keyProperty,
            )
        is StructDescriptor.Reflective<*, *> -> {
            val result =
                StructDescriptor(
                    recordId = RecordId.parse(descriptor.recordId()),
                    doc = descriptor.doc,
                    removedNumbers = descriptor.removedNumbers,
                )
            inProgress[descriptor] = result
            result.fields =
                descriptor.fields.map {
                    StructField(
                        name = it.name,
                        number = it.number,
                        type = notReflectiveImpl(it.type, inProgress),
                        doc = it.doc,
                    )
                }
            result
        }
        is EnumDescriptor.Reflective<*> -> {
            val result =
                EnumDescriptor(
                    recordId = RecordId.parse(descriptor.recordId()),
                    doc = descriptor.doc,
                    removedNumbers = descriptor.removedNumbers,
                )
            inProgress[descriptor] = result
            result.variants =
                descriptor.variants.map {
                    if (it is EnumWrapperVariant.Reflective<*, *>) {
                        EnumWrapperVariant(
                            name = it.name,
                            number = it.number,
                            type = notReflectiveImpl(it.type, inProgress),
                            doc = it.doc,
                        )
                    } else {
                        EnumConstantVariant(
                            name = it.name,
                            number = it.number,
                            doc = it.doc,
                        )
                    }
                }
            result
        }
    }
}

private fun asJsonCodeImpl(descriptor: TypeDescriptor): String {
    return formatReadableJson(asJsonImpl(descriptor))
}

private fun asJsonImpl(descriptor: TypeDescriptor): JsonObject {
    val recordIdToDefinition = mutableMapOf<String, JsonObject>()
    addRecordDefinitions(descriptor, recordIdToDefinition)
    return JsonObject(
        mapOf(
            "type" to getTypeSignature(descriptor),
            "records" to JsonArray(recordIdToDefinition.values.toList()),
        ),
    )
}

private fun getTypeSignature(typeDescriptor: TypeDescriptor): JsonObject {
    return when (typeDescriptor) {
        is PrimitiveDescriptor ->
            JsonObject(
                mapOf(
                    "kind" to JsonPrimitive("primitive"),
                    "value" to
                        JsonPrimitive(
                            when (typeDescriptor.primitiveType) {
                                PrimitiveType.BOOL -> "bool"
                                PrimitiveType.INT_32 -> "int32"
                                PrimitiveType.INT_64 -> "int64"
                                PrimitiveType.UINT_64 -> "hash64"
                                PrimitiveType.FLOAT_32 -> "float32"
                                PrimitiveType.FLOAT_64 -> "float64"
                                PrimitiveType.TIMESTAMP -> "timestamp"
                                PrimitiveType.STRING -> "string"
                                PrimitiveType.BYTES -> "bytes"
                            },
                        ),
                ),
            )
        is OptionalDescriptor ->
            JsonObject(
                mapOf(
                    "kind" to JsonPrimitive("optional"),
                    "value" to getTypeSignature(typeDescriptor.otherType),
                ),
            )
        is ArrayDescriptor ->
            JsonObject(
                mapOf(
                    "kind" to JsonPrimitive("array"),
                    "value" to
                        JsonObject(
                            if (typeDescriptor.keyProperty != null) {
                                mapOf(
                                    "item" to getTypeSignature(typeDescriptor.itemType),
                                    "key_extractor" to JsonPrimitive(typeDescriptor.keyProperty),
                                )
                            } else {
                                mapOf(
                                    "item" to getTypeSignature(typeDescriptor.itemType),
                                )
                            },
                        ),
                ),
            )
        is RecordDescriptor<*> ->
            JsonObject(
                mapOf(
                    "kind" to JsonPrimitive("record"),
                    "value" to JsonPrimitive("${typeDescriptor.modulePath}:${typeDescriptor.qualifiedName}"),
                ),
            )
    }
}

private fun addRecordDefinitions(
    typeDescriptor: TypeDescriptorBase,
    recordIdToDefinition: MutableMap<String, JsonObject>,
) {
    when (typeDescriptor) {
        is PrimitiveDescriptor -> {}
        is OptionalDescriptor -> addRecordDefinitions(typeDescriptor.otherType, recordIdToDefinition)
        is ArrayDescriptor -> addRecordDefinitions(typeDescriptor.itemType, recordIdToDefinition)
        is StructDescriptor -> {
            val recordId = typeDescriptor.recordId()
            if (recordIdToDefinition.containsKey(recordId)) {
                return
            }
            val recordDefinition =
                JsonObjectBuilder()
                    .put("kind", JsonPrimitive("struct"))
                    .put("id", JsonPrimitive(recordId))
                    .putUnlessEmpty("doc", JsonPrimitive(typeDescriptor.doc))
                    .put(
                        "fields",
                        JsonArray(
                            typeDescriptor.fields.map {
                                JsonObjectBuilder()
                                    .put("name", JsonPrimitive(it.name))
                                    .put("number", JsonPrimitive(it.number))
                                    .put("type", getTypeSignature(it.type))
                                    .putUnlessEmpty("doc", JsonPrimitive(it.doc))
                                    .build()
                            },
                        ),
                    )
                    .putUnlessEmpty(
                        "removed_numbers",
                        JsonArray(typeDescriptor.removedNumbers.map { JsonPrimitive(it) }),
                    )
                    .build()
            recordIdToDefinition[recordId] = JsonObject(recordDefinition)
            val dependencies = typeDescriptor.fields.map { it.type }
            for (dependency in dependencies) {
                addRecordDefinitions(dependency, recordIdToDefinition)
            }
        }
        is EnumDescriptor -> {
            val recordId = typeDescriptor.recordId()
            if (recordIdToDefinition.containsKey(recordId)) {
                return
            }
            val recordDefinition =
                JsonObjectBuilder()
                    .put("kind", JsonPrimitive("enum"))
                    .put("id", JsonPrimitive(recordId))
                    .putUnlessEmpty("doc", JsonPrimitive(typeDescriptor.doc))
                    .put(
                        "variants",
                        JsonArray(
                            typeDescriptor.variants.map {
                                JsonObjectBuilder()
                                    .put("name", JsonPrimitive(it.name))
                                    .put("number", JsonPrimitive(it.number))
                                    .putUnlessEmpty(
                                        "type",
                                        if (it is EnumWrapperVariant) getTypeSignature(it.type) else JsonPrimitive(""),
                                    )
                                    .putUnlessEmpty("doc", JsonPrimitive(it.doc))
                                    .build()
                            },
                        ),
                    )
                    .putUnlessEmpty(
                        "removed_numbers",
                        JsonArray(typeDescriptor.removedNumbers.map { JsonPrimitive(it) }),
                    )
                    .build()
            recordIdToDefinition[recordId] = JsonObject(recordDefinition)
            val dependencies = typeDescriptor.variants.mapNotNull { (it as? EnumWrapperVariant)?.type }
            for (dependency in dependencies) {
                addRecordDefinitions(dependency, recordIdToDefinition)
            }
        }
    }
}
