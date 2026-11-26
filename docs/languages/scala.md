# Scala

This guide explains how to use Skir in a Scala 3 project.

## Set up

In your `skir.yml` file, add the following snippet under `generators`:

```yaml
- mod: skir-scala-gen
  outDir: ./src/main/scala/skirout
  config: {}
  # Alternatively:
  # outDir: ./src/main/scala/my/project/skirout
  # config:
  #   packagePrefix: my.project.
```

The generated Scala code has a runtime dependency on `build.skir:skir-client`. Add this line to your `build.gradle.kts` file in the `dependencies` section:

```kotlin
implementation("build.skir:skir-client:latest.release")
```

Or in `build.sbt`:

```scala
libraryDependencies += "build.skir" % "skir-client" % "latest.release"
```

## Generated code guide

The examples below are for the code generated from [this](https://github.com/gepheum/skir-scala-example/blob/main/skir-src/user.skir) .skir file.

### Referring to generated symbols

```scala
// Import the given symbols from the Scala module generated from "user.skir"
import skirout.user.User
import skirout.user.UserRegistry
import skirout.user.SubscriptionStatus
import skirout.user.TARZAN

// Now you can use: TARZAN, User, UserRegistry, SubscriptionStatus, etc.
```

### Structs

For every struct `S` in the `.skir` file, Skir generates a frozen (deeply immutable) class `S`, a mutable class `S.Mutable`, and a sealed trait `S_OrMutable` implemented by both.

#### Frozen structs

```scala
import java.util.List

// Construct a frozen User.
val john = User(
  userId = 42,
  name = "John Doe",
  quote = "Coffee is just a socially acceptable form of rage.",
  pets = List.of(
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

// john.name = "John Smith"
// ^ Does not compile: all the properties are read-only
```

#### Partial construction

```scala
import java.util.List

// With .partial(), you don't need to specify all the fields of the struct.
val jane = User.partial(
  userId = 43,
  name = "Jane Doe",
  pets = List.of(
    User.Pet.partial(
      name = "Fido",
      picture = "🐶",
    ),
  ),
)

// Missing fields are initialized to their default values.
assert(jane.quote == "")

// User.partial() with no arguments (or User.default) returns an instance of
// User with all fields set to their default values.
assert(User.partial().pets.isEmpty)
```

#### Creating modified copies

```scala
// User.copy() creates a shallow copy of the struct with the specified fields
// modified.
val evilJohn = john.copy(
  name = "Evil John",
  quote = "I solemnly swear I am up to no good.",
)
assert(evilJohn.name == "Evil John")
assert(evilJohn.userId == 42)
```

#### Mutable structs

```scala
// User.Mutable is a mutable class similar to User.
val lyla = new User.Mutable()
lyla.userId = 44
lyla.name = "Lyla Doe"

val userHistory = new UserHistory.Mutable()
userHistory.user = lyla
// ^ The right-hand side of the assignment can be either frozen or mutable.
```

#### Mutable accessors

```scala
// The 'mutableUser' getter provides access to a mutable version of 'user'.
// If 'user' is already mutable, it returns it directly.
// If 'user' is frozen, it creates a mutable shallow copy, assigns it to
// 'user', and returns it.

// The user is currently 'lyla', which is mutable.
assert(userHistory.mutableUser eq lyla)
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
lyla.mutablePets.add(new User.Pet.Mutable(name = "Cupcake"))
```

#### Converting between frozen and mutable structs

```scala
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

#### Writing logic agnostic of mutability

```scala
// 'User_OrMutable' is a sealed trait that both 'User' and 'User.Mutable'
// extend.
def greet(user: User_OrMutable): Unit =
  println(s"Hello, ${user.name}")

greet(jane)
// Hello, Jane Doe
greet(lyla)
// Hello, Lyla Doe
```

### Enums

Skir generates a deeply immutable sealed abstract class for every enum in the `.skir` file.

The definition of the `SubscriptionStatus` enum in the `.skir` file is:

```skir
enum SubscriptionStatus {
  free;
  trial: Trial;
  premium;
}
```

#### Making enum values

```scala
import java.time.Instant

val someStatuses = Seq(
  // The UNKNOWN constant is present in all Skir enums even if it is not
  // declared in the .skir file.
  SubscriptionStatus.UNKNOWN,
  SubscriptionStatus.FREE,
  SubscriptionStatus.PREMIUM,
  // Skir generates one subclass {VariantName}Wrapper for every wrapper
  // variant. The constructor / apply method expects the value to wrap.
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

#### Conditions on enums

```scala
import java.time.Instant

assert(john.subscriptionStatus == SubscriptionStatus.FREE)

// UNKNOWN is the default value for enums.
assert(jane.subscriptionStatus == SubscriptionStatus.UNKNOWN)

val now = Instant.now()
val trialStatus: SubscriptionStatus =
  SubscriptionStatus.TrialWrapper(
    SubscriptionStatus.Trial(startTime = now),
  )

assert(
  trialStatus.isInstanceOf[SubscriptionStatus.TrialWrapper] &&
    trialStatus.asInstanceOf[SubscriptionStatus.TrialWrapper].value.startTime == now,
)
```

#### Branching on enum variants

```scala
def getInfoText(status: SubscriptionStatus): String =
  status match {
    case SubscriptionStatus.FREE               => "Free user"
    case SubscriptionStatus.PREMIUM            => "Premium user"
    case SubscriptionStatus.TrialWrapper(t)    => s"On trial since ${t.startTime}"
    case _: SubscriptionStatus.Unknown         => "Unknown subscription status"
  }

println(getInfoText(john.subscriptionStatus))
// "Free user"
```

### Serialization

Every frozen struct and enum companion object has a `serializer` method which returns a `build.skir.Serializer[T]` for serializing and deserializing instances.

```scala
import build.skir.JsonFlavor

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
//   "subscription_status": "free"
// }

// Serialize 'john' to binary format.
val johnBytes = serializer.toBytes(john)
```

#### Deserialization

```scala
import build.skir.JsonFlavor

// Use fromJson(), fromJsonCode() and fromBytes() to deserialize.
val reserializedJohn: User = serializer.fromJsonCode(johnDenseJson)
assert(reserializedJohn == john)

// fromJson/fromJsonCode can deserialize both dense and readable JSON
val reserializedEvilJohn: User =
  serializer.fromJsonCode(
    serializer.toJsonCode(evilJohn, JsonFlavor.READABLE),
  )
assert(reserializedEvilJohn == evilJohn)

assert(serializer.fromBytes(johnBytes) == john)
```

#### Primitive serializers

```scala
import build.skir.Serializers
import okio.ByteString
import java.time.Instant

assert(Serializers.bool().toJsonCode(true) == "1")
assert(Serializers.int32().toJsonCode(3) == "3")
assert(
  Serializers.int64().toJsonCode(9223372036854775807L) ==
    "\"9223372036854775807\"",
)
assert(
  Serializers.javaHash64().toJsonCode(java.lang.Long.parseUnsignedLong("18446744073709551615")) ==
    "\"18446744073709551615\"",
)
assert(
  Serializers.timestamp().toJsonCode(Instant.ofEpochMilli(1743682787000L)) ==
    "1743682787000",
)
assert(Serializers.float32().toJsonCode(3.14f) == "3.14")
assert(Serializers.float64().toJsonCode(3.14) == "3.14")
assert(Serializers.string().toJsonCode("Foo") == "\"Foo\"")
assert(
  Serializers.bytes().toJsonCode(ByteString.of(1.toByte, 2.toByte, 3.toByte)) ==
    "\"AQID\"",
)
```

#### Composite serializers

```scala
import build.skir.Serializers
import java.util.List
import java.util.Optional

assert(
  Serializers.javaOptional(Serializers.string()).toJsonCode(Optional.of("foo")) ==
    "\"foo\"",
)
assert(
  Serializers.javaOptional(Serializers.string()).toJsonCode(Optional.empty()) ==
    "null",
)

assert(
  Serializers.list(Serializers.bool()).toJsonCode(List.of(true, false)) ==
    "[1,0]",
)
```

### Constants

```scala
println(TARZAN)
// {
//   "user_id": 123,
//   "name": "Tarzan",
//   "quote": "AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA",
//   "pets": [
//     {
//       "name": "Cheeta",
//       "height_in_meters": 1.67,
//       "picture": "🐒"
//     }
//   ],
//   "subscription_status": {
//     "kind": "trial",
//     "value": {
//       "start_time": {
//         "unix_millis": 1743592409000,
//         "formatted": "2025-04-02T11:13:29Z"
//       }
//     }
//   }
// }
```

### Keyed lists

```scala
import java.util.List

// In the .skir file:
//   struct UserRegistry {
//     users: [User|user_id];
//   }

val userRegistry = UserRegistry(users = List.of(john, jane, evilJohn))

// findByKey() returns the user with the given key (specified in the .skir file).
// In this example, the key is the user id.
// The first lookup runs in O(N) time, and the following lookups run in O(1)
// time.
assert(userRegistry.users.findByKey(43L) eq jane)

// If multiple elements have the same key, the last one is returned.
assert(userRegistry.users.findByKey(42L) eq evilJohn)
assert(userRegistry.users.findByKey(100L) == null)
```

### Frozen lists and copies

```scala
import java.util.ArrayList

// Since all Skir objects are deeply immutable, all lists contained in a
// Skir object are also deeply immutable.
// This section helps understand when lists are copied and when they are
// not.
val pets = new ArrayList[User.Pet]()
pets.add(User.Pet.partial(name = "Fluffy", picture = "🐶"))
pets.add(User.Pet.partial(name = "Fido", picture = "🐻"))

val jade = User.partial(
  name = "Jade",
  pets = pets,
  // ^ 'pets' is mutable, so Skir makes an immutable shallow copy of it
)

assert(pets == jade.pets)
assert(!(pets eq jade.pets))

val jack = User.partial(
  name = "Jack",
  pets = jade.pets,
  // ^ 'jade.pets' is already immutable, so Skir does not make a copy
)

assert(jack.pets eq jade.pets)
```

### SkirRPC services

**Starting a SkirRPC service on an HTTP server** - full example [here](https://github.com/gepheum/skir-scala-example/blob/main/src/main/scala/examples/StartService.scala).

**Sending RPCs to a SkirRPC service** - full example [here](https://github.com/gepheum/skir-scala-example/blob/main/src/main/scala/examples/CallService.scala).

### Reflection

Reflection allows you to inspect a Skir type at runtime.

```scala
import build.skir.reflection.StructDescriptor
import build.skir.reflection.TypeDescriptor
import scala.jdk.CollectionConverters.*

println(
  User.typeDescriptor.getFields.asScala.map(_.getName).toList,
)
// List(user_id, name, quote, pets, subscription_status)

// A type descriptor can be serialized to JSON and deserialized later.
val typeDescriptor =
  TypeDescriptor.Companion.parseFromJsonCode(
    User.serializer.typeDescriptor().asJsonCode(),
  )

assert(typeDescriptor.isInstanceOf[StructDescriptor])
assert(typeDescriptor.asInstanceOf[StructDescriptor].getFields.size() == 5)
```

Full reflection example (`allStringsToUpperCase`) [here](https://github.com/gepheum/skir-scala-example/blob/main/src/main/scala/examples/AllStringsToUpperCase.scala).
