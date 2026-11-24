import { CodeBlock, H1, H2, H3, H4, InlineCode, P, Prose } from '@/components/prose'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Kotlin - Skir Documentation',
  description: 'Learn how to use Skir-generated Kotlin code in your projects',
}

export default function KotlinPage() {
  return (
    <Prose>
      <H1>Kotlin</H1>
      <P>This guide explains how to use Skir in a Kotlin project.</P>

      <H2>Set up</H2>
      <P>
        In your <InlineCode>skir.yml</InlineCode> file, add the following snippet under{' '}
        <InlineCode>generators</InlineCode>:
      </P>
      <CodeBlock language="yaml">{`- mod: skir-kotlin-gen
  outDir: ./src/main/kotlin/skirout
  config: {}
  # Alternatively:
  # outDir: ./src/main/kotlin/my/project/skirout
  # config:
  #   packagePrefix: my.project.`}</CodeBlock>
      <P>
        The generated Kotlin code has a runtime dependency on{' '}
        <InlineCode>build.skir:skir-client</InlineCode>. Add this line to your{' '}
        <InlineCode>build.gradle.kts</InlineCode> file in the <InlineCode>dependencies</InlineCode>{' '}
        section:
      </P>
      <CodeBlock language="kotlin">{`implementation("build.skir:skir-client:latest.release")`}</CodeBlock>
      <P>
        For more information, see this Kotlin project{' '}
        <a
          href="https://github.com/gepheum/skir-kotlin-example"
          target="_blank"
          rel="noopener noreferrer"
        >
          example
        </a>
        .
      </P>

      <H2>Generated code guide</H2>
      <P>
        The examples below are for the code generated from{' '}
        <a
          href="https://github.com/gepheum/skir-kotlin-example/blob/main/skir-src/user.skir"
          target="_blank"
          rel="noopener noreferrer"
        >
          this
        </a>{' '}
        .skir file.
      </P>

      <H3>Referring to generated symbols</H3>
      <CodeBlock language="kotlin">{`// Import the given symbols from the Kotlin module generated from "user.skir"
import skirout.user.User
import skirout.user.UserRegistry
import skirout.user.SubscriptionStatus
import skirout.user.TARZAN

// Now you can use: TARZAN, User, UserRegistry, SubscriptionStatus, etc.`}</CodeBlock>

      <H3>Structs</H3>
      <P>
        For every struct S in the .skir file, Skir generates a frozen (deeply immutable) class{' '}
        <InlineCode>S</InlineCode> and a mutable class <InlineCode>S.Mutable</InlineCode>.
      </P>
      <H4>Frozen structs</H4>
      <CodeBlock language="kotlin">{`// Construct a frozen User.
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
// ^ Does not compile: all the properties are read-only`}</CodeBlock>

      <H4>Partial construction</H4>
      <CodeBlock language="kotlin">{`// With .partial(), you don't need to specify all the fields of the struct.
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
assert(User.partial().pets.isEmpty())`}</CodeBlock>

      <H4>Creating modified copies</H4>
      <CodeBlock language="kotlin">{`// User.copy() creates a shallow copy of the struct with the specified fields
// modified.
val evilJohn =
    john.copy(
        name = "Evil John",
        quote = "I solemnly swear I am up to no good.",
    )
assert(evilJohn.name == "Evil John")
assert(evilJohn.userId == 42)`}</CodeBlock>

      <H4>Mutable structs</H4>
      <CodeBlock language="kotlin">{`// User.Mutable is a dataclass similar to User except it is mutable.
val lyla = User.Mutable()
lyla.userId = 44
lyla.name = "Lyla Doe"

val userHistory = UserHistory.Mutable()
userHistory.user = lyla
// ^ The right-hand side of the assignment can be either frozen or mutable.`}</CodeBlock>

      <H4>Mutable accessors</H4>
      <CodeBlock language="kotlin">{`// The 'mutableUser' getter provides access to a mutable version of 'user'.
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
// ^ Does not compile: 'User.pets' is read-only`}</CodeBlock>

      <H4>Converting between frozen and mutable structs</H4>
      <CodeBlock language="kotlin">{`// toMutable() does a shallow copy of the frozen struct, so it's cheap. All
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
assert(evilJane.userId == 43)`}</CodeBlock>

      <H4>Type aliases for frozen or mutable</H4>
      <CodeBlock language="kotlin">{`// 'User_OrMutable' is a type alias for the sealed class that both 'User' and
// 'User.Mutable' implement.
val greet: (User_OrMutable) -> Unit = {
    println("Hello, $it")
}

greet(jane)
// Hello, Jane Doe
greet(lyla)
// Hello, Lyla Doe`}</CodeBlock>

      <H3>Enums</H3>
      <P>
        Skir generates a deeply immutable Kotlin class for every enum in the .skir file. This class
        is not a Kotlin enum, although the syntax for referring to constants is similar.
      </P>
      <CodeBlock language="kotlin">{`val someStatuses =
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
    )`}</CodeBlock>

      <H4>Conditions on enums</H4>
      <CodeBlock language="kotlin">{`assert(john.subscriptionStatus == SubscriptionStatus.FREE)

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
)`}</CodeBlock>

      <H4>Branching on enum variants</H4>
      <CodeBlock language="kotlin">{`val getInfoText: (SubscriptionStatus) -> String = {
    when (it) {
        SubscriptionStatus.FREE -> "Free user"
        SubscriptionStatus.PREMIUM -> "Premium user"
        is SubscriptionStatus.TrialWrapper -> "On trial since \${it.value.startTime}"
        is SubscriptionStatus.Unknown -> "Unknown subscription status"
    }
}

println(getInfoText(john.subscriptionStatus))
// "Free user"`}</CodeBlock>

      <H3>Serialization</H3>
      <P>
        Every frozen struct class and enum class has a static <InlineCode>serializer</InlineCode>{' '}
        property which can be used for serializing and deserializing instances of the class.
      </P>
      <CodeBlock language="kotlin">{`val serializer = User.serializer

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
// likely to matter, which should be rare.`}</CodeBlock>

      <H4>Deserialization</H4>
      <CodeBlock language="kotlin">{`// Use fromJson(), fromJsonCode() and fromBytes() to deserialize.
val reserializedJohn: User = serializer.fromJsonCode(johnDenseJson)
assert(reserializedJohn.equals(john))

// fromJson/fromJsonCode can deserialize both dense and readable JSON
val reserializedEvilJohn: User =
    serializer.fromJsonCode(
        serializer.toJsonCode(john, JsonFlavor.READABLE),
    )
assert(reserializedEvilJohn.equals(evilJohn))

assert(serializer.fromBytes(johnBytes).equals(john))`}</CodeBlock>

      <H4>Primitive serializers</H4>
      <CodeBlock language="kotlin">{`assert(Serializers.bool.toJsonCode(true) == "1")
assert(Serializers.int32.toJsonCode(3) == "3")
assert(Serializers.int64.toJsonCode(9223372036854775807) == "\\\"9223372036854775807\\\"")
assert(
    Serializers.hash64.toJsonCode(BigInteger("18446744073709551615")) ==
        "\\\"18446744073709551615\\\""
)
assert(
    Serializers.timestamp.toJsonCode(Instant.ofEpochMilli(1743682787000)) ==
        "1743682787000"
)
assert(Serializers.float32.toJsonCode(3.14f) == "3.14")
assert(Serializers.float64.toJsonCode(3.14) == "3.14")
assert(Serializers.string.toJsonCode("Foo") == "\\"Foo\\"")
assert(
    Serializers.bytes.toJsonCode(byteArrayOf(1, 2, 3)) == "\\"AQID\\""
)`}</CodeBlock>

      <H4>Composite serializers</H4>
      <CodeBlock language="kotlin">{`assert(Serializers.optional(Serializers.string).toJsonCode("foo") == "\\"foo\\"")
assert(Serializers.optional(Serializers.string).toJsonCode(null) == "null")

assert(Serializers.list(Serializers.bool).toJsonCode(listOf(true, false)) == "[1,0]")`}</CodeBlock>

      <H3>Constants</H3>
      <CodeBlock language="kotlin">{`println(TARZAN)
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
// )`}</CodeBlock>

      <H3>Keyed lists</H3>
      <CodeBlock language="kotlin">{`// In the .skir file:
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
assert(userRegistry.users.findByKey(100) == null)`}</CodeBlock>

      <H3>Frozen lists and copies</H3>
      <CodeBlock language="kotlin">{`// Since all Skir objects are deeply immutable, all lists contained in a
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

assert(jack.pets === jade.pets)`}</CodeBlock>

      <H3>SkirRPC services</H3>
      <P>
        <strong>Starting a SkirRPC service on an HTTP server</strong> - full example{' '}
        <a
          href="https://github.com/gepheum/skir-kotlin-example/blob/main/src/main/kotlin/startservice/StartService.kt"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>
      <P>
        <strong>Sending RPCs to a SkirRPC service</strong> - full example{' '}
        <a
          href="https://github.com/gepheum/skir-kotlin-example/blob/main/src/main/kotlin/callservice/CallService.kt"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>

      <H3>Reflection</H3>
      <P>Reflection allows you to inspect a skir type at runtime.</P>
      <CodeBlock language="kotlin">{`println(
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
assert((typeDescriptor as StructDescriptor).fields.size == 5)`}</CodeBlock>

      <H2>Java codegen versus Kotlin codegen</H2>
      <P>
        While Java and Kotlin code can interoperate seamlessly, skir provides separate code
        generators for each language to leverage their unique strengths and idioms. For instance,
        the Kotlin generator utilizes named parameters for struct construction, whereas the Java
        generator employs the builder pattern.
      </P>
      <P>
        Although it's technically feasible to use Kotlin-generated code in a Java project (or vice
        versa), doing so results in an API that feels unnatural and cumbersome in the calling
        language. For the best developer experience, use the code generator that matches your
        project's primary language.
      </P>
      <P>
        Note that both the Java and Kotlin generated code share the same runtime dependency:{' '}
        <InlineCode>build.skir:skir-client</InlineCode>.
      </P>
    </Prose>
  )
}
