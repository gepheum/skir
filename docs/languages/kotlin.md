[![npm](https://img.shields.io/npm/v/skir-kotlin-gen)](https://www.npmjs.com/package/skir-kotlin-gen)
[![build](https://github.com/gepheum/skir-kotlin-gen/workflows/Build/badge.svg)](https://github.com/gepheum/skir-kotlin-gen/actions)

# Skir's Kotlin code generator

Official plugin for generating Kotlin code from [.skir](https://github.com/gepheum/skir) files.

## Set up

In your `skir.yml` file, add the following snippet under `generators`:
```yaml
  - mod: skir-kotlin-gen
    outDir: ./src/main/kotlin/skirout
    config: {}
    # Alternatively:
    # outDir: ./src/main/kotlin/my/project/skirout
    # config:
    #   packagePrefix: my.project.
```

The generated Kotlin code has a runtime dependency on `build.skir:skir-client`. Add this line to your `build.gradle.kts` file in the `dependencies` section:

```kotlin
implementation("build.skir:skir-client:latest.release")
```

For more information, see this Kotlin project [example](https://github.com/gepheum/skir-kotlin-example).

## Kotlin generated code guide

The examples below are for the code generated from [this](https://github.com/gepheum/skir-kotlin-example/blob/main/skir-src/user.skir) .skir file.

### Referring to generated symbols

```kotlin
// Import the given symbols from the Kotlin module generated from "user.skir"
import skirout.user.User
import skirout.user.UserRegistry
import skirout.user.SubscriptionStatus
import skirout.user.TARZAN

// Now you can use: TARZAN, User, UserRegistry, SubscriptionStatus, etc.
```

### Frozen struct classes

For every struct S in the .skir file, skir generates a frozen (deeply immutable) class `S` and a mutable class `S.Mutable`.

```kotlin
// Construct a frozen User.
val john =
    User(
        userId = 42,
        name = "John Doe",
        quote = "Coffee is just a socially acceptable form of rage.",
        pets =
            listOf(
                User.Pet(
                    name = "Dumbo",
                    heightInMeters = 1.0f,
                    picture = "🐘",
                ),
            ),
        subscriptionStatus = SubscriptionStatus.FREE,
        // foo = "bar",
        // ^ Does not compile: 'foo' is not a field of User
    )

assert(john.name == "John Doe")

// john.name = "John Smith";
// ^ Does not compile: all the properties are read-only
```

#### Partial construction

```kotlin
// With .partial(), you don't need to specify all the fields of the struct.
val jane =
    User.partial(
        userId = 43,
        name = "Jane Doe",
        pets =
            listOf(
                User.Pet.partial(
                    name = "Fido",
                    picture = "🐶",
                ),
            ),
    )

// Missing fields are initialized to their default values.
assert(jane.quote == "")

// User.partial() with no arguments returns an instance of User with all
// fields set to their default values.
assert(User.partial().pets.isEmpty())
```

#### Creating modified copies

```kotlin
// User.copy() creates a shallow copy of the struct with the specified fields
// modified.
val evilJohn =
    john.copy(
        name = "Evil John",
        quote = "I solemnly swear I am up to no good.",
    )
assert(evilJohn.name == "Evil John")
assert(evilJohn.userId == 42)
```

### Mutable struct classes

`User.Mutable` is a dataclass similar to User except it is mutable.

```kotlin
val lyla = User.Mutable()
lyla.userId = 44
lyla.name = "Lyla Doe"

val userHistory = UserHistory.Mutable()
userHistory.user = lyla
// ^ The right-hand side of the assignment can be either frozen or mutable.
```

#### Mutable accessors

```kotlin
// The 'mutableUser' getter provides access to a mutable version of 'user'.
// If 'user' is already mutable, it returns it directly.
// If 'user' is frozen, it creates a mutable shallow copy, assigns it to
// 'user', and returns it.

// The user is currently 'lyla', which is mutable.
assert(userHistory.mutableUser === lyla)
// Now assign a frozen User to 'user'.
userHistory.user = john
// Since 'john' is frozen, mutableUser makes a mutable shallow copy of it.
userHistory.mutableUser.name = "John the Second"
assert(userHistory.user.name == "John the Second")
assert(userHistory.user.userId == 42)

// Similarly, 'mutablePets' provides access to a mutable version of 'pets'.
// It returns the existing list if already mutable, or creates and returns a
// mutable shallow copy.
lyla.mutablePets.add(
    User.Pet(
        name = "Simba",
        heightInMeters = 0.4f,
        picture = "🦁",
    ),
)
lyla.mutablePets.add(User.Pet.Mutable(name = "Cupcake"))

// lyla.pets.add(User.Pet.Mutable(name = "Cupcake"));
// ^ Does not compile: 'User.pets' is read-only
```

### Converting between frozen and mutable structs

```kotlin
// toMutable() does a shallow copy of the frozen struct, so it's cheap. All
// the properties of the copy hold a frozen value.
val evilJaneBuilder = jane.toMutable()
evilJaneBuilder.name = "Evil Jane"
evilJaneBuilder.mutablePets.add(
    User.Pet(
        name = "Shadow",
        heightInMeters = 0.5f,
        picture = "🐺",
    ),
)

// toFrozen() recursively copies the mutable values held by properties of the
// object.
val evilJane = evilJaneBuilder.toFrozen()

assert(evilJane.name == "Evil Jane")
assert(evilJane.userId == 43)
```

#### Type aliases for frozen or mutable

```kotlin
// 'User_OrMutable' is a type alias for the sealed class that both 'User' and
// 'User.Mutable' implement.
val greet: (User_OrMutable) -> Unit = {
    println("Hello, $it")
}

greet(jane)
// Hello, Jane Doe
greet(lyla)
// Hello, Lyla Doe
```

### Enum classes

Skir generates a deeply immutable Kotlin class for every enum in the .skir file. This class is *not* a Kotlin enum, although the syntax for referring to constants is similar.

```kotlin
val someStatuses =
    listOf(
        // The UNKNOWN constant is present in all Skir enums even if it is not
        // declared in the .skir file.
        SubscriptionStatus.UNKNOWN,
        SubscriptionStatus.FREE,
        SubscriptionStatus.PREMIUM,
        // Skir generates one subclass {VariantName}Wrapper for every wrapper
        // variant. The constructor of this subclass expects the value to
        // wrap.
        SubscriptionStatus.TrialWrapper(
            SubscriptionStatus.Trial(
                startTime = Instant.now(),
            ),
        ),
        // Same as above (^), with a more concise syntax.
        // Available when the wrapped value is a struct.
        SubscriptionStatus.createTrial(
            startTime = Instant.now(),
        ),
    )
```

### Conditions on enums

```kotlin
assert(john.subscriptionStatus == SubscriptionStatus.FREE)

// UNKNOWN is the default value for enums.
assert(jane.subscriptionStatus == SubscriptionStatus.UNKNOWN)

val now = Instant.now()
val trialStatus: SubscriptionStatus =
    SubscriptionStatus.TrialWrapper(
        Trial(startTime = now),
    )

assert(
    trialStatus is SubscriptionStatus.TrialWrapper &&
        trialStatus.value.startTime == now,
)
```

#### Branching on enum variants

```kotlin
val getInfoText: (SubscriptionStatus) -> String = {
    when (it) {
        SubscriptionStatus.FREE -> "Free user"
        SubscriptionStatus.PREMIUM -> "Premium user"
        is SubscriptionStatus.TrialWrapper -> "On trial since ${it.value.startTime}"
        is SubscriptionStatus.Unknown -> "Unknown subscription status"
    }
}

println(getInfoText(john.subscriptionStatus))
// "Free user"
```

### Serialization

Every frozen struct class and enum class has a static `serializer` property which can be used for serializing and deserializing instances of the class.

```kotlin
val serializer = User.serializer

// Serialize 'john' to dense JSON.
val johnDenseJson: String = serializer.toJsonCode(john)

println(johnDenseJson)
// [42,"John Doe",...]

// Serialize 'john' to readable JSON.
println(serializer.toJsonCode(john, JsonFlavor.READABLE))
// {
//   "user_id": 42,
//   "name": "John Doe",
//   "quote": "Coffee is just a socially acceptable form of rage.",
//   "pets": [
//     {
//       "name": "Dumbo",
//       "height_in_meters": 1.0,
//       "picture": "🐘"
//     }
//   ],
//   "subscription_status": "FREE"
// }

// The dense JSON flavor is the flavor you should pick if you intend to
// deserialize the value in the future. Skir allows fields to be renamed,
// and because field names are not part of the dense JSON, renaming a field
// does not prevent you from deserializing the value.
// You should pick the readable flavor mostly for debugging purposes.

// Serialize 'john' to binary format.
val johnBytes = serializer.toBytes(john)

// The binary format is not human readable, but it is slightly more compact
// than JSON, and serialization/deserialization can be a bit faster in
// languages like C++. Only use it when this small performance gain is
// likely to matter, which should be rare.
```

### Deserialization

```kotlin
// Use fromJson(), fromJsonCode() and fromBytes() to deserialize.
val reserializedJohn: User = serializer.fromJsonCode(johnDenseJson)
assert(reserializedJohn.equals(john))

// fromJson/fromJsonCode can deserialize both dense and readable JSON
val reserializedEvilJohn: User =
    serializer.fromJsonCode(
        serializer.toJsonCode(john, JsonFlavor.READABLE),
    )
assert(reserializedEvilJohn.equals(evilJohn))

assert(serializer.fromBytes(johnBytes).equals(john))
```

### Primitive serializers

```kotlin
assert(Serializers.bool.toJsonCode(true) == "1")
assert(Serializers.int32.toJsonCode(3) == "3")
assert(Serializers.int64.toJsonCode(9223372036854775807) == "\"9223372036854775807\"")
assert(
    Serializers.hash64.toJsonCode(BigInteger("18446744073709551615")) ==
        "\"18446744073709551615\""
)
assert(
    Serializers.timestamp.toJsonCode(Instant.ofEpochMilli(1743682787000)) ==
        "1743682787000"
)
assert(Serializers.float32.toJsonCode(3.14f) == "3.14")
assert(Serializers.float64.toJsonCode(3.14) == "3.14")
assert(Serializers.string.toJsonCode("Foo") == "\"Foo\"")
assert(
    Serializers.bytes.toJsonCode(byteArrayOf(1, 2, 3)) == "\"AQID\""
)
```

### Composite serializers

```kotlin
assert(Serializers.optional(Serializers.string).toJsonCode("foo") == "\"foo\"")
assert(Serializers.optional(Serializers.string).toJsonCode(null) == "null")

assert(Serializers.list(Serializers.bool).toJsonCode(listOf(true, false)) == "[1,0]")
```

### Constants

```kotlin
println(TARZAN)
// User(
//   userId = 123,
//   name = "Tarzan",
//   quote = "AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA",
//   pets = listOf(
//     User.Pet(
//       name = "Cheeta",
//       heightInMeters = 1.67F,
//       picture = "🐒",
//     ),
//   ),
//   subscriptionStatus = SubscriptionStatus.TrialWrapper(
//     SubscriptionStatus.Trial(
//       startTime = Instant.ofEpochMillis(
//         // 2025-04-02T11:13:29Z
//         1743592409000L
//       ),
//     )
//   ),
// )
```

### Keyed lists

```kotlin
// In the .skir file:
//   struct UserRegistry {
//     users: [User|user_id];
//   }

val userRegistry = UserRegistry(users = listOf(john, jane, evilJohn))

// find() returns the user with the given key (specified in the .skir file).
// In this example, the key is the user id.
// The first lookup runs in O(N) time, and the following lookups run in O(1)
// time.
assert(userRegistry.users.findByKey(43) === jane)

// If multiple elements have the same key, the last one is returned.
assert(userRegistry.users.findByKey(42) === evilJohn)
assert(userRegistry.users.findByKey(100) == null)
```

### Frozen lists and copies

```kotlin
// Since all Skir objects are deeply immutable, all lists contained in a
// Skir object are also deeply immutable.
// This section helps understand when lists are copied and when they are
// not.
val pets: MutableList<Pet> =
    mutableListOf(
        Pet.partial(name = "Fluffy", picture = "🐶"),
        Pet.partial(name = "Fido", picture = "🐻"),
    )

val jade =
    User.partial(
        name = "Jade",
        pets = pets,
        // ^ 'pets' is mutable, so Skir makes an immutable shallow copy of it
    )

assert(pets == jade.pets)
assert(pets !== jade.pets)

val jack =
    User.partial(
        name = "Jack",
        pets = jade.pets,
        // ^ 'jade.pets' is already immutable, so Skir does not make a copy
    )

assert(jack.pets === jade.pets)
```

### Skir services

#### Starting a SkirRPC service on an HTTP server

Full example [here](https://github.com/gepheum/skir-kotlin-example/blob/main/src/main/kotlin/startservice/StartService.kt).

#### Sending RPCs to a SkirRPC service

Full example [here](https://github.com/gepheum/skir-kotlin-example/blob/main/src/main/kotlin/callservice/CallService.kt).

### Reflection

Reflection allows you to inspect a skir type at runtime.

```kotlin
println(
    User.typeDescriptor
        .fields
        .map { field -> field.name }
        .toList(),
)
// [user_id, name, quote, pets, subscription_status]

// A type descriptor can be serialized to JSON and deserialized later.
val typeDescriptor =
    TypeDescriptor.parseFromJsonCode(
        User.serializer.typeDescriptor.asJsonCode(),
    )

assert(typeDescriptor is StructDescriptor)
assert((typeDescriptor as StructDescriptor).fields.size == 5)

// The 'allStringsToUpperCase' function uses reflection to convert all the
// strings contained in a given Skir value to upper case.
// See the implementation at
// https://github.com/gepheum/skir-kotlin-example/blob/main/src/main/kotlin/AllStringsToUpperCase.kt
println(allStringsToUpperCase(TARZAN, User.typeDescriptor))
// User(
// userId = 123,
// name = "TARZAN",
// quote = "AAAAAAAAAAYAAAAAAAAAAYAAAAAAAAAA",
// pets = listOf(
//     User.Pet(
//     name = "CHEETA",
//     heightInMeters = 1.67F,
//     picture = "🐒",
//     ),
// ),
// subscriptionStatus = SubscriptionStatus.TrialWrapper(
//     SubscriptionStatus.Trial(
//     startTime = Instant.ofEpochMillis(
//         // 2025-04-02T11:13:29Z
//         1743592409000L
//     ),
//     )
// ),
// )
```

## Java codegen versus Kotlin codegen

While Java and Kotlin code can interoperate seamlessly, skir provides separate code generators for each language to leverage their unique strengths and idioms. For instance, the Kotlin generator utilizes named parameters for struct construction, whereas the Java generator employs the builder pattern. 

Although it's technically feasible to use Kotlin-generated code in a Java project (or vice versa), doing so results in an API that feels unnatural and cumbersome in the calling language. For the best developer experience, use the code generator that matches your project's primary language.

Note that both the Java and Kotlin generated code share the same runtime dependency: `build.skir:skir-client`.
