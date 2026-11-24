import { CodeBlock, H1, H2, H3, H4, InlineCode, P, Prose } from '@/components/prose'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Swift - Skir Documentation',
  description: 'Learn how to use Skir-generated Swift code in your projects',
}

export default function SwiftPage() {
  return (
    <Prose>
      <H1>Swift</H1>
      <P>This guide explains how to use Skir in a Swift project. Targets Swift 5.9 and higher.</P>

      <H2>Set up</H2>
      <P>
        In your <InlineCode>skir.yml</InlineCode> file, add the following snippet under{' '}
        <InlineCode>generators</InlineCode>:
      </P>
      <CodeBlock language="yaml">{`- mod: skir-swift-gen
  outDir: ./Sources/skirout
  config:
    # Generated symbols will have internal visibility
    public: false`}</CodeBlock>
      <P>Or if you want multiple targets in your Swift project:</P>
      <CodeBlock language="yaml">{`- mod: skir-swift-gen
  outDir: ./Sources/MyLib/skirout
  config:
    # Generated symbols will have public visibility
    public: true`}</CodeBlock>
      <P>
        The generated Swift code has a runtime dependency on the{' '}
        <InlineCode>skir-swift-client</InlineCode> package. Add it to your{' '}
        <InlineCode>Package.swift</InlineCode>:
      </P>
      <CodeBlock language="swift">{`dependencies: [
    .package(url: "https://github.com/gepheum/skir-swift-client", branch: "main"),
],`}</CodeBlock>
      <P>
        Then make sure the existing target that contains <InlineCode>outDir</InlineCode> links
        against <InlineCode>SkirClient</InlineCode>:
      </P>
      <CodeBlock language="swift">{`.target(
    name: "MyLib",
    dependencies: [
        .product(name: "SkirClient", package: "skir-swift-client"),
    ],
    path: "Sources/MyLib"
),`}</CodeBlock>
      <P>
        For more information, see this Swift project{' '}
        <a
          href="https://github.com/gepheum/skir-swift-example"
          target="_blank"
          rel="noopener noreferrer"
        >
          example
        </a>
        .
      </P>

      <H2>Generated code guide</H2>
      <P>The examples below use the generated code style from the Swift example project.</P>

      <H3>Referring to generated symbols</H3>
      <P>
        The Skir code generator places every generated symbol inside a caseless enum named after its
        .skir file. For example, all types from <InlineCode>path/to/module.skir</InlineCode> live in{' '}
        <InlineCode>Path_To_Module_skir</InlineCode>. This keeps symbols from different modules
        unambiguous even when their names collide.
      </P>
      <P>
        When a name is unique across all modules, a short alias is provided in the generated{' '}
        <InlineCode>Skir</InlineCode> caseless enum:
      </P>
      <CodeBlock language="swift">{`let a: Service_skir.User = ...         // fully qualified
let b: Skir.User = ...                 // via the Skir convenience alias`}</CodeBlock>

      <H3>Struct types</H3>
      <P>
        Skir generates a Swift struct for every struct in the .skir file. Structs are immutable
        values and every field is a <InlineCode>let</InlineCode>.
      </P>
      <CodeBlock language="swift">{`// Construct a value using the generated initializer. Every field must be
// specified.
let john = Service_skir.User(
  userId: 42,
  name: "John Doe",
  quote: "Coffee is just a socially acceptable form of rage.",
  pets: [
    Service_skir.User.Pet(name: "Dumbo", heightInMeters: 1.0, picture: "🐘")
  ],
  subscriptionStatus: .free
)

print(john.name)  // John Doe

print(john)
// {
//    "user_id": 42,
//    ...
// }

// 'defaultValue' gives you a value with every field set to its zero value
// (0, "", empty array, ...):
print(Service_skir.User.defaultValue.name)    // (empty string)
print(Service_skir.User.defaultValue.userId)  // 0

// 'partial' is an alternative constructor where omitted fields default to their
// zero values. Use it when you only care about a few fields, for example in
// unit tests.
let jane = Service_skir.User.partial(userId: 43, name: "Jane Doe")
print(jane.quote)        // (empty string - defaulted)
print(jane.pets.count)   // 0 - defaulted

// Structs can be compared with ==
print(Service_skir.User.defaultValue == Service_skir.User.partial())
// true`}</CodeBlock>

      <H4>Creating modified copies</H4>
      <CodeBlock language="swift">{`// Create a modified copy without mutating the original using 'copy'.
    // Only the fields wrapped in '.set(...)' change; the rest are kept as-is.
let renamedJohn = john.copy(name: .set("John \"Coffee\" Doe"))
print(renamedJohn.name)    // John "Coffee" Doe
print(renamedJohn.userId)  // 42 (kept from john)
print(john.name)           // John Doe (john is unchanged)`}</CodeBlock>

      <H3>Enum types</H3>
      <P>
        Skir generates a Swift enum for every enum in the .skir file. The{' '}
        <InlineCode>.unknown</InlineCode> case is added automatically and is the default.
      </P>
      <P>
        The definition of the <InlineCode>SubscriptionStatus</InlineCode> enum in the .skir file is:
      </P>
      <CodeBlock language="skir">{`enum SubscriptionStatus {
  free;
  trial: Trial;
  premium;
}`}</CodeBlock>

      <H4>Making enum values</H4>
      <CodeBlock language="swift">{`let statuses: [Service_skir.SubscriptionStatus] = [
  .unknownValue,  // default "unknown" value
  .free,
  .premium,
  .trial(.partial(startTime: Date())),  // wrapper variant carrying a value
]`}</CodeBlock>

      <H4>Conditions on enums</H4>
      <CodeBlock language="swift">{`func describe(_ status: Skir.SubscriptionStatus) -> String {
  switch status {
  case .free:
    return "Free user"
  case .premium:
    return "Premium user"
  case .trial(let t):
    return "On trial since \(t.startTime)"
  case .unknown:
    return "Unknown subscription status"
  }
}

print(describe(john.subscriptionStatus))  // Free user`}</CodeBlock>

      <H3>Serialization</H3>
      <P>
        <InlineCode>User.serializer</InlineCode> returns a{' '}
        <InlineCode>Serializer&lt;User&gt;</InlineCode> which can serialise and deserialise
        instances of <InlineCode>User</InlineCode>.
      </P>
      <CodeBlock language="swift">{`let serializer = Skir.User.serializer

// Serialize to dense JSON (field-index-based; safe for storage and transport).
// Field names are NOT used, so renaming a field stays backward compatible.
let denseJson = serializer.toJson(john)
print(denseJson)
// [42,"John Doe",...]

// Serialize to readable (name-based, indented) JSON.
// Good for debugging; do NOT use for persistent storage.
let readableJson = serializer.toJson(john, readable: true)
// {
//   "user_id": 42,
//   "name": "John Doe",
//   ...
// }

// Deserialize from JSON (both dense and readable formats are accepted):
let johnFromJson = try! serializer.fromJson(denseJson)
assert(johnFromJson == john)

// Serialize to compact binary format.
let bytes = serializer.toBytes(john)
let johnFromBytes = try! serializer.fromBytes(bytes)
assert(johnFromBytes == john)`}</CodeBlock>

      <H3>Primitive serializers</H3>
      <CodeBlock language="swift">{`print(Serializers.bool.toJson(true))
// 1

print(Serializers.int32.toJson(3))
// 3

print(Serializers.int64.toJson(9_223_372_036_854_775_807))
// "9223372036854775807"
// int64 values are encoded as strings in JSON so that JavaScript parsers
// (which use 64-bit floats) cannot silently lose precision.

print(Serializers.float32.toJson(1.5))
// 1.5

print(Serializers.float64.toJson(1.5))
// 1.5

print(Serializers.string.toJson("Foo"))
// "Foo"

print(
  Serializers.timestamp.toJson(
    Date(timeIntervalSince1970: 1_703_984_028),
    readable: true))
// {
//   "unix_millis": 1703984028000,
//   "formatted": "2023-12-31T00:53:48.000Z"
// }

print(Serializers.bytes.toJson(Data([0xDE, 0xAD, 0xBE, 0xEF])))
// "3q2+7w=="`}</CodeBlock>

      <H3>Composite serializers</H3>
      <CodeBlock language="swift">{`// Optional serializer:
print(Serializers.optional(Serializers.string).toJson("foo"))
// "foo"

print(Serializers.optional(Serializers.string).toJson(nil as String?))
// null

// Array serializer:
print(Serializers.array(Serializers.bool).toJson([true, false]))
// [1,0]`}</CodeBlock>

      <H3>Constants</H3>
      <CodeBlock language="swift">{`// Skir generates a typed constant for every 'const' in the .skir file.
    // Access it via the module namespace or the 'Skir' alias:
let tarzan = Service_skir.tarzan  // same as Skir.tarzan
print(tarzan.name)   // Tarzan
print(tarzan.quote)  // AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA`}</CodeBlock>

      <H3>Keyed lists</H3>
      <CodeBlock language="swift">{`// In the .skir file:
//   struct UserRegistry {
//     users: [User|user_id];
//   }
// The '|user_id' suffix tells Skir to index the array by user_id, enabling
// O(1) lookup.
let registry = Service_skir.UserRegistry(users: [john, jane])

// findByKey returns the first element whose user_id matches.
// The index is built lazily on the first call and cached for subsequent calls.
print(registry.users.findByKey(43) != nil)   // true
print(registry.users.findByKey(43)! == jane) // true

// If no element has the given key, nil is returned.
print(registry.users.findByKey(999) == nil)  // true

// findByKeyOrDefault returns the zero-value element instead of nil.
let notFoundOrDefault = registry.users.findByKeyOrDefault(999)
print(notFoundOrDefault.pets.count)  // 0`}</CodeBlock>

      <H3>SkirRPC services</H3>
      <H4>Starting a SkirRPC service on an HTTP server</H4>
      <P>
        Full example{' '}
        <a
          href="https://github.com/gepheum/skir-swift-example/blob/main/Sources/StartService/main.swift"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>

      <H4>Sending RPCs to a SkirRPC service</H4>
      <P>
        Full example{' '}
        <a
          href="https://github.com/gepheum/skir-swift-example/blob/main/Sources/CallService/main.swift"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>

      <H3>Reflection</H3>
      <CodeBlock language="swift">{`// Reflection allows you to inspect a Skir type at runtime.
// Each generated type exposes its schema as a TypeDescriptor via its serializer.
let typeDescriptor = Skir.User.serializer.typeDescriptor

// A TypeDescriptor can be serialized to JSON and deserialized back:
let descriptorFromJson = try! Reflection.TypeDescriptor.parseFromJson(typeDescriptor.asJson())

// Pattern match to distinguish struct, enum, primitive descriptors:
if case .structRecord(let sd) = descriptorFromJson {
  print(sd)  // StructDescriptor(...:User)
}`}</CodeBlock>
    </Prose>
  )
}
