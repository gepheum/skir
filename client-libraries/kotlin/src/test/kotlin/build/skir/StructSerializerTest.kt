package build.skir

import build.skir.internal.StructSerializer
import build.skir.internal.UnrecognizedFields
import build.skir.internal.toStringImpl
import build.skir.reflection.TypeDescriptor
import com.google.common.truth.Truth.assertThat
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows

class StructSerializerTest {
    // Test data structures
    data class PersonFrozen(
        val name: String = "",
        val age: Int = 0,
        val email: String? = null,
        val isActive: Boolean = false,
        val tags: List<String> = emptyList(),
        val unrecognizedFields: UnrecognizedFields<PersonFrozen>? = null,
    )

    data class PersonMutable(
        var name: String = "",
        var age: Int = 0,
        var email: String? = null,
        var isActive: Boolean = false,
        var tags: List<String> = emptyList(),
        var unrecognizedFields: UnrecognizedFields<PersonFrozen>? = null,
    )

    private val defaultPerson = PersonFrozen()

    private val personStructSerializer =
        StructSerializer<PersonFrozen, PersonMutable>(
            "foo:Person",
            doc = "The person",
            defaultInstance = defaultPerson,
            newMutableFn = { PersonMutable() },
            toFrozenFn = { mutable ->
                PersonFrozen(
                    name = mutable.name,
                    age = mutable.age,
                    email = mutable.email,
                    isActive = mutable.isActive,
                    tags = mutable.tags,
                    unrecognizedFields = mutable.unrecognizedFields,
                )
            },
            getUnrecognizedFields = { frozen -> frozen.unrecognizedFields },
            setUnrecognizedFields = { mutable, fields -> mutable.unrecognizedFields = fields },
        ).apply {
            // Add fields in order by field number
            addField(
                name = "name",
                kotlinName = "name",
                number = 0,
                serializer = build.skir.Serializers.string,
                doc = "The name",
                getter = { it.name },
                setter = { mutable, value -> mutable.name = value },
            )
            addField(
                name = "age",
                kotlinName = "age",
                number = 1,
                serializer = build.skir.Serializers.int32,
                doc = "",
                getter = { it.age },
                setter = { mutable, value -> mutable.age = value },
            )
            addField(
                name = "email",
                kotlinName = "email",
                number = 2,
                serializer = build.skir.Serializers.optional(build.skir.Serializers.string),
                doc = "",
                getter = { it.email },
                setter = { mutable, value -> mutable.email = value },
            )
            addField(
                name = "is_active",
                kotlinName = "isActive",
                number = 3,
                serializer = build.skir.Serializers.bool,
                doc = "",
                getter = { it.isActive },
                setter = { mutable, value -> mutable.isActive = value },
            )
            addField(
                name = "tags",
                kotlinName = "tags",
                number = 4,
                serializer = build.skir.Serializers.list(build.skir.Serializers.string),
                doc = "",
                getter = { it.tags },
                setter = { mutable, value -> mutable.tags = value },
            )
            finalizeStruct()
        }

    private val personSerializer = Serializer(personStructSerializer)

    @Test
    fun `test struct serializer - default instance`() {
        // Test isDefault
        assertThat(personStructSerializer.isDefault(defaultPerson))
            .isTrue()

        val nonDefaultPerson = PersonFrozen(name = "John")
        assertThat(personStructSerializer.isDefault(nonDefaultPerson))
            .isFalse()

        // Test JSON serialization - default should be empty array/object
        val defaultDenseJson = personStructSerializer.toJson(defaultPerson, readableFlavor = false)
        assertThat(defaultDenseJson)
            .isInstanceOf(JsonArray::class.java)
        assertThat((defaultDenseJson as JsonArray))
            .isEmpty()

        val defaultReadableJson = personStructSerializer.toJson(defaultPerson, readableFlavor = true)
        assertThat(defaultReadableJson)
            .isInstanceOf(JsonObject::class.java)
        assertThat((defaultReadableJson as JsonObject))
            .isEmpty()

        // Test JSON deserialization
        assertThat(personStructSerializer.fromJson(JsonPrimitive(0), keepUnrecognizedValues = false))
            .isEqualTo(defaultPerson)
        assertThat(personStructSerializer.fromJson(JsonArray(emptyList()), keepUnrecognizedValues = false))
            .isEqualTo(defaultPerson)
        assertThat(personStructSerializer.fromJson(JsonObject(emptyMap()), keepUnrecognizedValues = false))
            .isEqualTo(defaultPerson)
    }

    @Test
    fun `test struct serializer - dense JSON format`() {
        val person =
            PersonFrozen(
                name = "Alice",
                age = 30,
                email = "alice@example.com",
                isActive = true,
                tags = listOf("developer", "kotlin"),
            )

        // Test dense JSON - should be an array
        val denseJson = personStructSerializer.toJson(person, readableFlavor = false)
        assertThat(denseJson)
            .isInstanceOf(JsonArray::class.java)

        val jsonArray = denseJson as JsonArray
        assertThat((jsonArray[0] as JsonPrimitive).content.removeSurrounding("\""))
            .isEqualTo("Alice")
        assertThat((jsonArray[1] as JsonPrimitive).content)
            .isEqualTo("30")
        assertThat((jsonArray[2] as JsonPrimitive).content.removeSurrounding("\""))
            .isEqualTo("alice@example.com")
        assertThat((jsonArray[3] as JsonPrimitive).content)
            .isEqualTo("1") // bool dense format
        assertThat(jsonArray[4])
            .isInstanceOf(JsonArray::class.java) // tags array

        // Test roundtrip
        val restored = personStructSerializer.fromJson(denseJson, keepUnrecognizedValues = false)
        assertThat(restored.name).isEqualTo(person.name)
        assertThat(restored.age).isEqualTo(person.age)
        assertThat(restored.email).isEqualTo(person.email)
        assertThat(restored.isActive).isEqualTo(person.isActive)
        assertThat(restored.tags).isEqualTo(person.tags)
    }

    @Test
    fun `test struct serializer - readable JSON format`() {
        val person =
            PersonFrozen(
                name = "Bob",
                age = 25,
                email = null,
                isActive = true,
                tags = listOf("tester"),
            )

        // Test readable JSON - should be an object with only non-default values
        val readableJson = personStructSerializer.toJson(person, readableFlavor = true)
        assertThat(readableJson)
            .isInstanceOf(JsonObject::class.java)

        val jsonObject = readableJson as JsonObject
        assertThat(jsonObject).containsKey("name")
        assertThat(jsonObject).containsKey("age")
        assertThat(jsonObject).doesNotContainKey("email") // null/default value should be omitted
        assertThat(jsonObject).containsKey("is_active")
        assertThat(jsonObject).containsKey("tags")

        // Test roundtrip
        val restored = personStructSerializer.fromJson(readableJson, keepUnrecognizedValues = false)
        assertThat(restored.name).isEqualTo(person.name)
        assertThat(restored.age).isEqualTo(person.age)
        assertThat(restored.email).isEqualTo(person.email)
        assertThat(restored.isActive).isEqualTo(person.isActive)
        assertThat(restored.tags).isEqualTo(person.tags)
    }

    @Test
    fun `test struct serializer - binary format small structs`() {
        // Test binary encoding for different struct sizes (0-3 fields)
        val emptyStruct = defaultPerson
        val oneFieldStruct = PersonFrozen(name = "Dave")
        val twoFieldStruct = PersonFrozen(name = "Eve", age = 28)
        val threeFieldStruct = PersonFrozen(name = "Frank", age = 30, email = "frank@example.com")

        // Empty struct should encode to wire 246 (0 fields)
        val emptyBytes = personSerializer.toBytes(emptyStruct)
        assertThat(emptyBytes.hex())
            .startsWith("736b6972f6") // skir prefix + 246

        // One field should encode to wire 247 (1 field)
        val oneFieldBytes = personSerializer.toBytes(oneFieldStruct)
        assertThat(oneFieldBytes.hex())
            .startsWith("736b6972f7") // skir prefix + 247

        // Two fields should encode to wire 248 (2 fields)
        val twoFieldBytes = personSerializer.toBytes(twoFieldStruct)
        assertThat(twoFieldBytes.hex())
            .startsWith("736b6972f8") // skir prefix + 248

        // Three fields should encode to wire 249 (3 fields)
        val threeFieldBytes = personSerializer.toBytes(threeFieldStruct)
        assertThat(threeFieldBytes.hex())
            .startsWith("736b6972f9") // skir prefix + 249

        // Test roundtrips
        assertThat(personSerializer.fromBytes(emptyBytes.toByteArray()))
            .isEqualTo(emptyStruct)
        assertThat(personSerializer.fromBytes(oneFieldBytes.toByteArray()))
            .isEqualTo(oneFieldStruct)
        assertThat(personSerializer.fromBytes(twoFieldBytes.toByteArray()))
            .isEqualTo(twoFieldStruct)
        assertThat(personSerializer.fromBytes(threeFieldBytes.toByteArray()))
            .isEqualTo(threeFieldStruct)
    }

    @Test
    fun `test struct serializer - binary format large structs`() {
        // Test struct with more than 3 fields (should use wire 250 + length prefix)
        val fullStruct =
            PersonFrozen(
                name = "Grace",
                age = 45,
                email = "grace@example.com",
                isActive = true,
                tags = listOf("manager", "leader"),
            )

        val bytes = personSerializer.toBytes(fullStruct)
        assertThat(bytes.hex())
            .startsWith("736b6972fa") // skir prefix + 250

        val restored = personSerializer.fromBytes(bytes.toByteArray())
        assertThat(restored.name).isEqualTo(fullStruct.name)
        assertThat(restored.age).isEqualTo(fullStruct.age)
        assertThat(restored.email).isEqualTo(fullStruct.email)
        assertThat(restored.isActive).isEqualTo(fullStruct.isActive)
        assertThat(restored.tags).isEqualTo(fullStruct.tags)
    }

    @Test
    fun `test struct serializer - all field types roundtrip`() {
        val testPerson =
            PersonFrozen(
                name = "John Doe",
                age = 42,
                email = "john.doe@example.com",
                isActive = true,
                tags = listOf("senior", "architect", "kotlin"),
            )

        // Test JSON roundtrip with both flavors
        val denseJson = personSerializer.toJsonCode(testPerson)
        val readableJson = personSerializer.toJsonCode(testPerson, JsonFlavor.READABLE)

        val restoredFromDense = personSerializer.fromJsonCode(denseJson)
        val restoredFromReadable = personSerializer.fromJsonCode(readableJson)

        // Both should restore to the same object
        assertThat(restoredFromDense.name).isEqualTo(testPerson.name)
        assertThat(restoredFromDense.age).isEqualTo(testPerson.age)
        assertThat(restoredFromDense.email).isEqualTo(testPerson.email)
        assertThat(restoredFromDense.isActive).isEqualTo(testPerson.isActive)
        assertThat(restoredFromDense.tags).isEqualTo(testPerson.tags)

        assertThat(restoredFromReadable.name).isEqualTo(testPerson.name)
        assertThat(restoredFromReadable.age).isEqualTo(testPerson.age)
        assertThat(restoredFromReadable.email).isEqualTo(testPerson.email)
        assertThat(restoredFromReadable.isActive).isEqualTo(testPerson.isActive)
        assertThat(restoredFromReadable.tags).isEqualTo(testPerson.tags)

        // Test binary roundtrip
        val bytes = personSerializer.toBytes(testPerson)
        val restoredFromBinary = personSerializer.fromBytes(bytes.toByteArray())

        assertThat(restoredFromBinary.name).isEqualTo(testPerson.name)
        assertThat(restoredFromBinary.age).isEqualTo(testPerson.age)
        assertThat(restoredFromBinary.email).isEqualTo(testPerson.email)
        assertThat(restoredFromBinary.isActive).isEqualTo(testPerson.isActive)
        assertThat(restoredFromBinary.tags).isEqualTo(testPerson.tags)
    }

    @Test
    fun `test struct serializer - error cases`() {
        // Test that finalizeStruct() can only be called once
        val testSerializer =
            StructSerializer<PersonFrozen, PersonMutable>(
                "foo:Person",
                doc = "",
                defaultInstance = defaultPerson,
                newMutableFn = { PersonMutable() },
                toFrozenFn = { PersonFrozen() },
                getUnrecognizedFields = { null },
                setUnrecognizedFields = { _, _ -> },
            )

        testSerializer.addField(
            "name",
            kotlinName = "name",
            0,
            build.skir.Serializers.string,
            doc = "",
            { it.name },
            { m, v -> m.name = v },
        )

        testSerializer.finalizeStruct()

        // Adding fields after finalization should throw
        assertThrows<IllegalStateException> {
            testSerializer.addField(
                "age",
                kotlinName = "age",
                1,
                build.skir.Serializers.int32,
                doc = "",
                { it.age },
                { m, v -> m.age = v },
            )
        }

        // Adding removed numbers after finalization should throw
        assertThrows<IllegalStateException> {
            testSerializer.addRemovedNumber(5)
        }

        // Double finalization should throw
        assertThrows<IllegalStateException> {
            testSerializer.finalizeStruct()
        }
    }

    @Test
    fun `test struct serializer - removed field numbers`() {
        // Test struct with removed field numbers
        data class SimpleStruct(val name: String = "", val value: Int = 0)

        data class SimpleMutable(var name: String = "", var value: Int = 0)
        val defaultSimple = SimpleStruct()

        val serializerWithRemovedFields =
            StructSerializer<SimpleStruct, SimpleMutable>(
                "foo:Simple",
                doc = "",
                defaultInstance = defaultSimple,
                newMutableFn = { SimpleMutable() },
                toFrozenFn = { mutable -> SimpleStruct(mutable.name, mutable.value) },
                getUnrecognizedFields = { null },
                setUnrecognizedFields = { _, _ -> },
            ).apply {
                addField("name", "name", 0, build.skir.Serializers.string, "", { it.name }, { m, v -> m.name = v })
                addRemovedNumber(1) // Field number 1 was removed
                addField("value", "value", 2, build.skir.Serializers.int32, "", { it.value }, { m, v -> m.value = v })
                finalizeStruct()
            }

        val testStruct = SimpleStruct("test", 42)
        val serializer = Serializer(serializerWithRemovedFields)

        // Test JSON roundtrips - should still work normally
        val denseJson = serializer.toJsonCode(testStruct)
        val readableJson = serializer.toJsonCode(testStruct, JsonFlavor.READABLE)

        val restoredFromDense = serializer.fromJsonCode(denseJson)
        val restoredFromReadable = serializer.fromJsonCode(readableJson)

        assertThat(restoredFromDense.name).isEqualTo(testStruct.name)
        assertThat(restoredFromDense.value).isEqualTo(testStruct.value)
        assertThat(restoredFromReadable.name).isEqualTo(testStruct.name)
        assertThat(restoredFromReadable.value).isEqualTo(testStruct.value)

        // Test binary roundtrip - should handle removed field properly
        val bytes = serializer.toBytes(testStruct)
        val restoredFromBinary = serializer.fromBytes(bytes.toByteArray())

        assertThat(restoredFromBinary.name).isEqualTo(testStruct.name)
        assertThat(restoredFromBinary.value).isEqualTo(testStruct.value)
    }

    @Test
    fun `test struct serializer - default detection`() {
        // Test isDefault with various field configurations

        // All default values
        val allDefaults = PersonFrozen()
        assertThat(personStructSerializer.isDefault(allDefaults))
            .isTrue()

        // One non-default value
        val oneNonDefault = PersonFrozen(name = "test")
        assertThat(personStructSerializer.isDefault(oneNonDefault))
            .isFalse()

        // Edge case: empty string vs default string
        val emptyString = PersonFrozen(name = "")
        assertThat(personStructSerializer.isDefault(emptyString))
            .isTrue() // empty string is default

        // Edge case: empty list vs default list
        val emptyList = PersonFrozen(tags = emptyList())
        assertThat(personStructSerializer.isDefault(emptyList))
            .isTrue() // empty list is default

        // Edge case: null vs non-null optional
        val nullOptional = PersonFrozen(email = null)
        assertThat(personStructSerializer.isDefault(nullOptional))
            .isTrue() // null is default for optional

        val nonNullOptional = PersonFrozen(email = "")
        assertThat(personStructSerializer.isDefault(nonNullOptional))
            .isFalse() // even empty string is non-default for optional

        // Complex case: multiple defaults with one non-default
        val mixedDefaults = PersonFrozen(name = "", age = 0, email = null, isActive = false, tags = listOf("test"))
        assertThat(personStructSerializer.isDefault(mixedDefaults))
            .isFalse() // tags makes it non-default
    }

    // Test data structures for unrecognized fields testing
    data class PartialPersonFrozen(
        val name: String = "",
        val age: Int = 0,
        val email: String? = null,
        val unrecognizedFields: UnrecognizedFields<PartialPersonFrozen>? = null,
    )

    data class PartialPersonMutable(
        var name: String = "",
        var age: Int = 0,
        var email: String? = null,
        var unrecognizedFields: UnrecognizedFields<PartialPersonFrozen>? = null,
    )

    // Partial serializer that only knows about the first 3 fields (name, age, email)
    private val partialPersonStructSerializer =
        StructSerializer<PartialPersonFrozen, PartialPersonMutable>(
            "foo:Person",
            doc = "",
            defaultInstance = PartialPersonFrozen(),
            newMutableFn = { PartialPersonMutable() },
            toFrozenFn = { mutable ->
                PartialPersonFrozen(
                    name = mutable.name,
                    age = mutable.age,
                    email = mutable.email,
                    unrecognizedFields = mutable.unrecognizedFields,
                )
            },
            getUnrecognizedFields = { frozen -> frozen.unrecognizedFields },
            setUnrecognizedFields = { mutable, fields -> mutable.unrecognizedFields = fields },
        ).apply {
            // Only add the first 3 fields
            addField(
                name = "name",
                kotlinName = "name",
                number = 0,
                serializer = build.skir.Serializers.string,
                doc = "",
                getter = { it.name },
                setter = { mutable, value -> mutable.name = value },
            )
            addField(
                name = "age",
                kotlinName = "age",
                number = 1,
                serializer = build.skir.Serializers.int32,
                doc = "",
                getter = { it.age },
                setter = { mutable, value -> mutable.age = value },
            )
            addField(
                name = "email",
                kotlinName = "email",
                number = 2,
                serializer = build.skir.Serializers.optional(build.skir.Serializers.string),
                doc = "",
                getter = { it.email },
                setter = { mutable, value -> mutable.email = value },
            )
            finalizeStruct()
        }

    private val partialPersonSerializer = Serializer(partialPersonStructSerializer)

    @Test
    fun `test unrecognized fields - JSON dense format roundtrip`() {
        // Create a full person with all fields set
        val fullPerson =
            PersonFrozen(
                name = "John Doe",
                age = 30,
                email = "john@example.com",
                isActive = true,
                tags = listOf("developer", "kotlin"),
            )

        // Step 1: Serialize with full serializer to dense JSON
        val fullJson = personSerializer.toJsonCode(fullPerson, JsonFlavor.DENSE)

        // Step 2: Deserialize with partial serializer (should capture unrecognized fields)
        val partialPerson = partialPersonSerializer.fromJsonCode(fullJson, UnrecognizedValuesPolicy.KEEP)

        // Verify the known fields are correct
        assertThat(partialPerson.name).isEqualTo("John Doe")
        assertThat(partialPerson.age).isEqualTo(30)
        assertThat(partialPerson.email).isEqualTo("john@example.com")

        // Verify unrecognized fields are captured
        assertThat(partialPerson.unrecognizedFields).isNotNull()
        assertThat(partialPerson.unrecognizedFields?.jsonElements).isNotNull()

        // Step 3: Serialize with partial serializer (should preserve unrecognized fields)
        val partialJson = partialPersonSerializer.toJsonCode(partialPerson)

        // Step 4: Deserialize with full serializer (should restore original values)
        val restoredPerson = personSerializer.fromJsonCode(partialJson)

        // Verify full roundtrip preserves all original values
        assertThat(restoredPerson.name).isEqualTo("John Doe")
        assertThat(restoredPerson.age).isEqualTo(30)
        assertThat(restoredPerson.email).isEqualTo("john@example.com")
        assertThat(restoredPerson.isActive).isEqualTo(true)
        assertThat(restoredPerson.tags).isEqualTo(listOf("developer", "kotlin"))
    }

    @Test
    fun `test unrecognized fields - JSON readable format roundtrip`() {
        // Create a full person with all fields set
        val fullPerson =
            PersonFrozen(
                name = "Jane Smith",
                age = 25,
                email = "jane@example.com",
                isActive = false,
                tags = listOf("manager", "team-lead"),
            )

        // Step 1: Serialize with full serializer to readable JSON
        val fullJson = personSerializer.toJsonCode(fullPerson, JsonFlavor.READABLE)

        // Step 2: Deserialize with partial serializer
        // Note: Readable format doesn't preserve unrecognized fields, so we only get known fields
        val partialPerson = partialPersonSerializer.fromJsonCode(fullJson, UnrecognizedValuesPolicy.KEEP)

        // Verify the known fields are correct
        assertThat(partialPerson.name).isEqualTo("Jane Smith")
        assertThat(partialPerson.age).isEqualTo(25)
        assertThat(partialPerson.email).isEqualTo("jane@example.com")

        // Readable format doesn't preserve unrecognized fields
        assertThat(partialPerson.unrecognizedFields).isNull()

        // Step 3: Serialize with partial serializer
        val partialJson = partialPersonSerializer.toJsonCode(partialPerson, JsonFlavor.READABLE)

        // Step 4: Deserialize with full serializer
        val restoredPerson = personSerializer.fromJsonCode(partialJson)

        // Verify known fields are preserved, unknown fields are defaults
        assertThat(restoredPerson.name).isEqualTo("Jane Smith")
        assertThat(restoredPerson.age).isEqualTo(25)
        assertThat(restoredPerson.email).isEqualTo("jane@example.com")
        assertThat(restoredPerson.isActive).isEqualTo(false) // default value
        assertThat(restoredPerson.tags).isEqualTo(emptyList<String>()) // default value
    }

    @Test
    fun `test unrecognized fields - binary format roundtrip`() {
        // Create a full person with all fields set
        val fullPerson =
            PersonFrozen(
                name = "Bob Wilson",
                age = 45,
                email = "bob@example.com",
                isActive = true,
                tags = listOf("senior", "architect", "mentor"),
            )

        // Step 1: Serialize with full serializer to binary
        val fullBytes = personSerializer.toBytes(fullPerson)

        // Step 2: Deserialize with partial serializer (should capture unrecognized fields)
        val partialPerson = partialPersonSerializer.fromBytes(fullBytes.toByteArray(), UnrecognizedValuesPolicy.KEEP)

        // Verify the known fields are correct
        assertThat(partialPerson.name).isEqualTo("Bob Wilson")
        assertThat(partialPerson.age).isEqualTo(45)
        assertThat(partialPerson.email).isEqualTo("bob@example.com")

        // Verify unrecognized fields are captured
        assertThat(partialPerson.unrecognizedFields).isNotNull()
        assertThat(partialPerson.unrecognizedFields?.bytes).isNotNull()

        // Step 3: Serialize with partial serializer (should preserve unrecognized fields)
        val partialBytes = partialPersonSerializer.toBytes(partialPerson)

        // Step 4: Deserialize with full serializer (should restore original values)
        val restoredPerson = personSerializer.fromBytes(partialBytes.toByteArray())

        // Verify full roundtrip preserves all original values
        assertThat(restoredPerson.name).isEqualTo("Bob Wilson")
        assertThat(restoredPerson.age).isEqualTo(45)
        assertThat(restoredPerson.email).isEqualTo("bob@example.com")
        assertThat(restoredPerson.isActive).isEqualTo(true)
        assertThat(restoredPerson.tags).isEqualTo(listOf("senior", "architect", "mentor"))
    }

    @Test
    fun `test unrecognized fields - without keepUnrecognizedValues`() {
        // Create a full person with all fields set
        val fullPerson =
            PersonFrozen(
                name = "Alice Brown",
                age = 35,
                email = "alice@example.com",
                isActive = true,
                tags = listOf("product-manager"),
            )

        // Step 1: Serialize with full serializer
        val fullJson = personSerializer.toJsonCode(fullPerson, JsonFlavor.DENSE)

        // Step 2: Deserialize with partial serializer WITHOUT keepUnrecognizedValues
        val partialPerson = partialPersonSerializer.fromJsonCode(fullJson)

        // Verify the known fields are correct
        assertThat(partialPerson.name).isEqualTo("Alice Brown")
        assertThat(partialPerson.age).isEqualTo(35)
        assertThat(partialPerson.email).isEqualTo("alice@example.com")

        // Verify unrecognized fields are NOT captured
        assertThat(partialPerson.unrecognizedFields).isNull()

        // Step 3: Serialize with partial serializer
        val partialJson = partialPersonSerializer.toJsonCode(partialPerson, JsonFlavor.DENSE)

        // Step 4: Deserialize with full serializer
        val restoredPerson = personSerializer.fromJsonCode(partialJson)

        // Verify known fields are preserved, unknown fields are defaults
        assertThat(restoredPerson.name).isEqualTo("Alice Brown")
        assertThat(restoredPerson.age).isEqualTo(35)
        assertThat(restoredPerson.email).isEqualTo("alice@example.com")
        assertThat(restoredPerson.isActive).isEqualTo(false) // default value
        assertThat(restoredPerson.tags).isEqualTo(emptyList<String>()) // default value
    }

    @Test
    fun `test unrecognized fields - partial struct with defaults`() {
        // Create a person with only some fields set (others are defaults)
        val fullPerson =
            PersonFrozen(
                name = "Charlie Davis",
                age = 0,
                email = null,
                isActive = true,
                tags = emptyList(),
            )

        // Step 1: Serialize with full serializer to dense JSON
        val fullJson = personSerializer.toJsonCode(fullPerson)

        // Step 2: Deserialize with partial serializer
        val partialPerson = partialPersonSerializer.fromJsonCode(fullJson, UnrecognizedValuesPolicy.KEEP)

        // Verify the known fields are correct
        assertThat(partialPerson.name).isEqualTo("Charlie Davis")
        assertThat(partialPerson.age).isEqualTo(0)
        assertThat(partialPerson.email).isEqualTo(null)

        // Should still have unrecognized fields even if some are defaults
        assertThat(partialPerson.unrecognizedFields).isNotNull()

        // Step 3: Roundtrip through partial serializer
        val partialJson = partialPersonSerializer.toJsonCode(partialPerson)
        val restoredPerson = personSerializer.fromJsonCode(partialJson)

        // Verify roundtrip preserves all values
        assertThat(restoredPerson.name).isEqualTo("Charlie Davis")
        assertThat(restoredPerson.age).isEqualTo(0)
        assertThat(restoredPerson.email).isEqualTo(null)
        assertThat(restoredPerson.isActive).isEqualTo(true) // should be preserved from unrecognized fields
        assertThat(restoredPerson.tags).isEqualTo(emptyList<String>()) // default preserved
    }

    @Test
    fun `test unrecognized fields - multiple roundtrips`() {
        // Create a full person
        val originalPerson =
            PersonFrozen(
                name = "Dave Evans",
                age = 28,
                email = "dave@example.com",
                isActive = false,
                tags = listOf("junior", "learning"),
            )

        var currentData = originalPerson

        // Do multiple roundtrips: full -> partial -> full
        for (i in 1..3) {
            // Full -> Binary -> Partial (with unrecognized fields)
            val fullBytes = personSerializer.toBytes(currentData)
            val partialPerson =
                partialPersonSerializer.fromBytes(
                    fullBytes.toByteArray(),
                    UnrecognizedValuesPolicy.KEEP,
                )

            // Partial -> Binary -> Full (restore from unrecognized fields)
            val partialBytes = partialPersonSerializer.toBytes(partialPerson)
            currentData = personSerializer.fromBytes(partialBytes.toByteArray())
        }

        // After multiple roundtrips, should still equal the original
        assertThat(currentData.name).isEqualTo(originalPerson.name)
        assertThat(currentData.age).isEqualTo(originalPerson.age)
        assertThat(currentData.email).isEqualTo(originalPerson.email)
        assertThat(currentData.isActive).isEqualTo(originalPerson.isActive)
        assertThat(currentData.tags).isEqualTo(originalPerson.tags)
    }

    @Test
    fun `test unrecognized fields - edge cases with empty and default values`() {
        // Test with default instance
        val defaultPerson = PersonFrozen() // all defaults

        // Full -> Partial -> Full roundtrip with defaults
        val fullJson = personSerializer.toJsonCode(defaultPerson, JsonFlavor.DENSE)
        val partialPerson = partialPersonSerializer.fromJsonCode(fullJson, UnrecognizedValuesPolicy.KEEP)
        val partialJson = partialPersonSerializer.toJsonCode(partialPerson, JsonFlavor.DENSE)
        val restoredPerson = personSerializer.fromJsonCode(partialJson)

        // Should be identical to original default
        assertThat(restoredPerson).isEqualTo(defaultPerson)

        // Test with empty JSON array
        val emptyArrayPerson = partialPersonSerializer.fromJsonCode("[]", UnrecognizedValuesPolicy.KEEP)
        assertThat(emptyArrayPerson).isEqualTo(PartialPersonFrozen())

        // Test with large slot count but mostly defaults
        val sparseFullPerson =
            PersonFrozen(
                name = "",
                age = 0,
                email = null,
                isActive = false,
                tags = listOf("only-this-matters"),
            )

        val sparseJson = personSerializer.toJsonCode(sparseFullPerson, JsonFlavor.DENSE)
        val sparsePartial = partialPersonSerializer.fromJsonCode(sparseJson, UnrecognizedValuesPolicy.KEEP)
        val restoredSparse =
            personSerializer.fromJsonCode(
                partialPersonSerializer.toJsonCode(sparsePartial, JsonFlavor.DENSE),
            )

        assertThat(restoredSparse.toString()).isEqualTo(sparseFullPerson.toString())
    }

    @Test
    fun `test toStringImpl() with partial`() {
        val person =
            PersonFrozen(
                name = "",
                age = 0,
                email = null,
                isActive = true,
                tags = listOf("foo"),
            )

        assertThat(toStringImpl(person, personSerializer.impl))
            .isEqualTo(
                "StructSerializerTest.PersonFrozen.partial(\n" +
                    "  isActive = true,\n" +
                    "  tags = listOf(\n" +
                    "    \"foo\",\n" +
                    "  ),\n" +
                    ")",
            )
    }

    @Test
    fun `test toStringImpl() with whole`() {
        val person =
            PersonFrozen(
                name = "John",
                age = 1,
                email = "john@example.com",
                isActive = true,
                tags = listOf("foo"),
            )

        assertThat(toStringImpl(person, personSerializer.impl))
            .isEqualTo(
                "StructSerializerTest.PersonFrozen(\n" +
                    "  name = \"John\",\n" +
                    "  age = 1,\n" +
                    "  email = \"john@example.com\",\n" +
                    "  isActive = true,\n" +
                    "  tags = listOf(\n" +
                    "    \"foo\",\n" +
                    "  ),\n" +
                    ")",
            )
    }

    @Test
    fun `test toStringImpl() with default instance`() {
        val person = PersonFrozen()

        assertThat(toStringImpl(person, personSerializer.impl))
            .isEqualTo("StructSerializerTest.PersonFrozen.partial()")
    }

    @Test
    fun `test struct serializer - typeDescriptor`() {
        val actualJson = personSerializer.typeDescriptor.asJsonCode()
        val expectedJson =
            "{\n" +
                "  \"type\": {\n" +
                "    \"kind\": \"record\",\n" +
                "    \"value\": \"foo:Person\"\n" +
                "  },\n" +
                "  \"records\": [\n" +
                "    {\n" +
                "      \"kind\": \"struct\",\n" +
                "      \"id\": \"foo:Person\",\n" +
                "      \"doc\": \"The person\",\n" +
                "      \"fields\": [\n" +
                "        {\n" +
                "          \"name\": \"name\",\n" +
                "          \"number\": 0,\n" +
                "          \"type\": {\n" +
                "            \"kind\": \"primitive\",\n" +
                "            \"value\": \"string\"\n" +
                "          },\n" +
                "          \"doc\": \"The name\"\n" +
                "        },\n" +
                "        {\n" +
                "          \"name\": \"age\",\n" +
                "          \"number\": 1,\n" +
                "          \"type\": {\n" +
                "            \"kind\": \"primitive\",\n" +
                "            \"value\": \"int32\"\n" +
                "          }\n" +
                "        },\n" +
                "        {\n" +
                "          \"name\": \"email\",\n" +
                "          \"number\": 2,\n" +
                "          \"type\": {\n" +
                "            \"kind\": \"optional\",\n" +
                "            \"value\": {\n" +
                "              \"kind\": \"primitive\",\n" +
                "              \"value\": \"string\"\n" +
                "            }\n" +
                "          }\n" +
                "        },\n" +
                "        {\n" +
                "          \"name\": \"is_active\",\n" +
                "          \"number\": 3,\n" +
                "          \"type\": {\n" +
                "            \"kind\": \"primitive\",\n" +
                "            \"value\": \"bool\"\n" +
                "          }\n" +
                "        },\n" +
                "        {\n" +
                "          \"name\": \"tags\",\n" +
                "          \"number\": 4,\n" +
                "          \"type\": {\n" +
                "            \"kind\": \"array\",\n" +
                "            \"value\": {\n" +
                "              \"item\": {\n" +
                "                \"kind\": \"primitive\",\n" +
                "                \"value\": \"string\"\n" +
                "              }\n" +
                "            }\n" +
                "          }\n" +
                "        }\n" +
                "      ]\n" +
                "    }\n" +
                "  ]\n" +
                "}"
        assertThat(actualJson).isEqualTo(expectedJson)

        assertThat(
            TypeDescriptor.parseFromJson(personSerializer.typeDescriptor.asJson()).asJsonCode(),
        ).isEqualTo(expectedJson)
    }
}
