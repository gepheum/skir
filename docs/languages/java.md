[![npm](https://img.shields.io/npm/v/skir-java-gen)](https://www.npmjs.com/package/skir-java-gen)
[![build](https://github.com/gepheum/skir-java-gen/workflows/Build/badge.svg)](https://github.com/gepheum/skir-java-gen/actions)

# Skir's Java code generator

Official plugin for generating Java code from [.skir](https://github.com/gepheum/skir) files.

## Set up

In your `skir.yml` file, add the following snippet under `generators`:
```yaml
  - mod: skir-java-gen
    outDir: ./src/main/java/skirout
    config: {}
    # Alternatively:
    # outDir: ./src/main/kotlin/my/project/skirout
    # config:
    #   packagePrefix: my.project.
```

The generated Java code has a runtime dependency on `build.skir:skir-client`. Add this line to your `build.gradle` file in the `dependencies` section:

```gradle
implementation 'build.skir:skir-client:latest.release'
```

For more information, see this Java project [example](https://github.com/gepheum/skir-java-example).

## Java generated code guide

The examples below are for the code generated from [this](https://github.com/gepheum/skir-java-example/blob/main/skir-src/user.skir) .skir file.

### Referring to generated symbols

```java
// Import the given symbols from the Java module generated from "user.skir"
import skirout.user.User;
import skirout.user.UserRegistry;
import skirout.user.SubscriptionStatus;
import skirout.user.Constants;

// Now you can use: Constants.TARZAN, User, UserRegistry, SubscriptionStatus, etc.
```

### Struct classes

skir generates a deeply immutable Java class for every struct in the .skir file.

```java
// To construct a User, use the builder pattern.

final User john =
    User.builder()
        // All fields are required. The compiler will error if you miss one or if
        // you don't specify them in alphabetical order.
        .setName("John Doe")
        .setPets(
            List.of(
                User.Pet.builder()
                    .setHeightInMeters(1.0f)
                    .setName("Dumbo")
                    .setPicture("🐘")
                    .build()))
        .setQuote("Coffee is just a socially acceptable form of rage.")
        .setSubscriptionStatus(SubscriptionStatus.FREE)
        .setUserId(42)
        .build();

assert john.name().equals("John Doe");

// john.pets().clear();
// ^ Runtime error: the list is deeply immutable.

// With partialBuilder(), you are not required to specify all the fields,
// and there is no constraint on the order.
final User jane = User.partialBuilder().setUserId(43).setName("Jane Doe").build();

// Fields not explicitly set are initialized to their default values.
assert jane.quote().equals("");
assert jane.pets().equals(List.of());

// User.DEFAULT is an instance of User with all fields set to their default
// values.
assert User.DEFAULT.name().equals("");
assert User.DEFAULT.userId() == 0;
```

#### Creating modified copies

```java
// toBuilder() creates a builder initialized with the values of this instance.
// This is useful for creating a modified copy of an existing object.
final User evilJohn =
    john.toBuilder()
        // Like with partialBuilder(), there is no constraint on the order.
        .setName("Evil John")
        .setQuote("I solemnly swear I am up to no good.")
        .build();

assert evilJohn.name().equals("Evil John");
assert evilJohn.userId() == 42;
```

### Enum classes

skir generates a deeply immutable Java class for every enum in the .skir file. This class is *not* a Java enum, although the syntax for referring to constants is similar.

The definition of the `SubscriptionStatus` enum in the .skir file is:
```rust
enum SubscriptionStatus {
  free;
  trial: Trial;
  premium;
}
```

#### Making enum values

```java
final List<SubscriptionStatus> someStatuses =
    List.of(
        // The UNKNOWN constant is present in all skir enums even if it is not
        // declared in the .skir file.
        SubscriptionStatus.UNKNOWN,
        SubscriptionStatus.FREE,
        SubscriptionStatus.PREMIUM,
        // To construct wrapper variants, call the wrap{VariantName} static
        // methods.
        SubscriptionStatus.wrapTrial(
            SubscriptionStatus.Trial.builder()
                .setStartTime(Instant.now())
                .build()));
```

#### Conditions on enums

```java
assert john.subscriptionStatus().equals(SubscriptionStatus.FREE);

// UNKNOWN is the default value for enums.
assert jane.subscriptionStatus().equals(SubscriptionStatus.UNKNOWN);

final Instant now = Instant.now();
final SubscriptionStatus trialStatus =
    SubscriptionStatus.wrapTrial(
        SubscriptionStatus.Trial.builder()
            .setStartTime(now)
            .build());

assert trialStatus.kind() == SubscriptionStatus.Kind.TRIAL_WRAPPER;
assert trialStatus.asTrial().startTime() == now;

// SubscriptionStatus.FREE.asTrial();
// ^ Runtime error: asTrial() can only be called on a trial wrapper.
```

#### Branching on enum variants

```java
// First way to branch on enum variants: switch on kind()
final Function<SubscriptionStatus, String> getInfoText =
    status ->
        switch (status.kind()) {
          case FREE_CONST -> "Free user";
          case PREMIUM_CONST -> "Premium user";
          case TRIAL_WRAPPER -> "On trial since " + status.asTrial().startTime();
          case UNKNOWN -> "Unknown subscription status";
          default -> throw new AssertionError("Unreachable");
        };

System.out.println(getInfoText.apply(john.subscriptionStatus()));
// "Free user"

// Second way to branch on enum variants: visitor pattern.
// It is a bit more verbose, but it adds compile-time safety and it gives
// you a guarantee that all variants are handled.
final SubscriptionStatus.Visitor<String> infoTextVisitor =
    new SubscriptionStatus.Visitor<>() {
      @Override
      public String onFree() {
        return "Free user";
      }

      @Override
      public String onPremium() {
        return "Premium user";
      }

      @Override
      public String onTrial(SubscriptionStatus.Trial trial) {
        return "On trial since " + trial.startTime();
      }

      @Override
      public String onUnknown() {
        return "Unknown subscription status";
      }
    };

System.out.println(john.subscriptionStatus().accept(infoTextVisitor));
// "Free user"
```

### Serialization

Every frozen struct class and enum class has a static readonly `SERIALIZER` property which can be used for serializing and deserializing instances of the class.

```java
final Serializer<User> serializer = User.SERIALIZER;

// Serialize 'john' to dense JSON.
final String johnDenseJson = serializer.toJsonCode(john);
System.out.println(johnDenseJson);
// [42,"John Doe",...]

// Serialize 'john' to readable JSON.
System.out.println(serializer.toJsonCode(john, JsonFlavor.READABLE));
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
final ByteString johnBytes = serializer.toBytes(john);
System.out.println(johnBytes);

// The binary format is not human readable, but it is slightly more compact
// than JSON, and serialization/deserialization can be a bit faster in
// languages like C++. Only use it when this small performance gain is
// likely to matter, which should be rare.
```

### Deserialization

```java
// Use fromJson(), fromJsonCode() and fromBytes() to deserialize.

final User reserializedJohn = serializer.fromJsonCode(johnDenseJson);
assert reserializedJohn.equals(john);

final User reserializedEvilJohn =
    serializer.fromJsonCode(
        // fromJson/fromJsonCode can deserialize both dense and readable JSON
        serializer.toJsonCode(john, JsonFlavor.READABLE));
assert reserializedEvilJohn.equals(evilJohn);

assert serializer.fromBytes(johnBytes).equals(john);
```

### Primitive serializers

```java
assert Serializers.bool().toJsonCode(true).equals("1");
assert Serializers.int32().toJsonCode(3).equals("3");
assert Serializers.int64().toJsonCode(9223372036854775807L).equals("\"9223372036854775807\"");
assert Serializers.javaHash64()
    .toJsonCode(new BigInteger("18446744073709551615"))
    .equals("\"18446744073709551615\"");
assert Serializers.timestamp()
    .toJsonCode(Instant.ofEpochMilli(1743682787000L))
    .equals("1743682787000");
assert Serializers.float32().toJsonCode(3.14f).equals("3.14");
assert Serializers.float64().toJsonCode(3.14).equals("3.14");
assert Serializers.string().toJsonCode("Foo").equals("\"Foo\"");
assert Serializers.bytes()
    .toJsonCode(ByteString.of((byte) 1, (byte) 2, (byte) 3))
    .equals("\"AQID\"");
```

### Composite serializers

```java
assert Serializers.javaOptional(Serializers.string())
    .toJsonCode(java.util.Optional.of("foo"))
    .equals("\"foo\"");
assert Serializers.javaOptional(Serializers.string())
    .toJsonCode(java.util.Optional.empty())
    .equals("null");

assert Serializers.list(Serializers.bool()) //
    .toJsonCode(List.of(true, false))
    .equals("[1,0]");
```

### Frozen lists and copies

```java
// Since all Skir objects are deeply immutable, all lists contained in a
// Skir object are also deeply immutable.
// This section helps understand when lists are copied and when they are
// not.

final List<User.Pet> pets = new ArrayList<>();
pets.add(
    User.Pet.builder()
        .setHeightInMeters(0.25f)
        .setName("Fluffy")
        .setPicture("🐶")
        .build());
pets.add(
    User.Pet.builder()
        .setHeightInMeters(0.5f)
        .setName("Fido")
        .setPicture("🐻")
        .build());

final User jade =
    User.partialBuilder()
        .setName("Jade")
        .setPets(pets)
        // 'pets' is mutable, so Skir makes an immutable shallow copy of it
        .build();

assert pets.equals(jade.pets());
assert pets != jade.pets();

final User jack =
    User.partialBuilder()
        .setName("Jack")
        .setPets(jade.pets())
        // The list is already immutable, so Skir does not make a copy
        .build();

assert jack.pets() == jade.pets();
```

### Keyed lists

```java
final UserRegistry userRegistry =
    UserRegistry.builder().setUsers(List.of(john, jane, evilJohn)).build();

// find() returns the user with the given key (specified in the .skir file).
// In this example, the key is the user id.
// The first lookup runs in O(N) time, and the following lookups run in O(1)
// time.
assert userRegistry.users().findByKey(43) == jane;
// If multiple elements have the same key, the last one is returned.
assert userRegistry.users().findByKey(42) == evilJohn;
assert userRegistry.users().findByKey(100) == null;
```

### Constants

```java
System.out.println(Constants.TARZAN);
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

### SkirRPC services

#### Starting a SkirRPC service on an HTTP server

Full example [here](https://github.com/gepheum/skir-java-example/blob/main/src/main/java/examples/StartService.java).

#### Sending RPCs to a SkirRPC service

Full example [here](https://github.com/gepheum/skir-java-example/blob/main/src/main/java/examples/CallService.java).

### Reflection

Reflection allows you to inspect a skir type at runtime.

```java
import build.skir.reflection.StructDescriptor;
import build.skir.reflection.TypeDescriptor;

System.out.println(
    User.TYPE_DESCRIPTOR
        .getFields()
        .stream()
        .map((field) -> field.getName())
        .toList());
// [user_id, name, quote, pets, subscription_status]

// A type descriptor can be serialized to JSON and deserialized later.
final TypeDescriptor typeDescriptor =
    TypeDescriptor.Companion.parseFromJsonCode(
        User.SERIALIZER.typeDescriptor().asJsonCode());

assert typeDescriptor instanceof StructDescriptor;
assert ((StructDescriptor) typeDescriptor).getFields().size() == 5;

// The 'allStringsToUpperCase' function uses reflection to convert all the
// strings contained in a given skir value to upper case.
// See the implementation at
// https://github.com/gepheum/skir-java-example/blob/main/src/main/java/examples/AllStringsToUpperCase.java
System.out.println(
    AllStringsToUpperCase.allStringsToUpperCase(
        Constants.TARZAN, User.TYPE_DESCRIPTOR));
// {
//   "user_id": 123,
//   "name": "TARZAN",
//   "quote": "AAAAAAAAAAYAAAAAAAAAAYAAAAAAAAAA",
//   "pets": [
//     {
//       "name": "CHEETA",
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

## Java codegen versus Kotlin codegen

While Java and Kotlin code can interoperate seamlessly, skir provides separate code generators for each language to leverage their unique strengths and idioms. For instance, the Kotlin generator utilizes named parameters for struct construction, whereas the Java generator employs the builder pattern. 

Although it's technically feasible to use Kotlin-generated code in a Java project (or vice versa), doing so results in an API that feels unnatural and cumbersome in the calling language. For the best developer experience, use the code generator that matches your project's primary language.

Note that both the Java and Kotlin generated code share the same runtime dependency: `build.skir:skir-client`.

