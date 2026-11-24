// Code snippets showing how to use Swift-generated data types.
//
// Run with: swift run Snippets

import Foundation
import MyLib
import SkirClient

// =============================================================================
// MODULES AND NAMESPACING
// =============================================================================

// The Skir code generator places every generated symbol inside a caseless
// enum named after its .skir file — for example, all types from
// "path/to/module.skir" live in "Path_To_Module_skir". This keeps symbols from
// different modules unambiguous even when their names collide.
//
// When a name is unique across all modules, a short alias is provided in the
// generated "Skir" caseless enum. The two forms below are identical:
//
//   let a: Service_skir.User = ...   // fully qualified
//   let b: Skir.User = ...           // via the Skir convenience alias
//
// Use whichever is clearest. In the examples below we start with the fully
// qualified form so the relationship is obvious, then switch to the shorter
// alias for brevity.

// =============================================================================
// STRUCT TYPES
// =============================================================================

// Skir generates a Swift struct for every struct in the .skir file.
// Structs are immutable values — every field is a `let`.

// Construct a value using the generated initializer. Every field must be
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

// `defaultValue` gives you a value with every field set to its zero value
// (0, "", empty array, …):
print(Service_skir.User.defaultValue.name)  // (empty string)
print(Service_skir.User.defaultValue.userId)  // 0

// `partial` is an alternative constructor where omitted fields default to their
// zero values. Use it when you only care about a few fields, for example in
// unit tests.
let jane = Service_skir.User.partial(userId: 43, name: "Jane Doe")
print(jane.quote)  // (empty string — defaulted)
print(jane.pets.count)  // 0 — defaulted

// Structs can be compared with ==
print(Service_skir.User.defaultValue == Service_skir.User.partial())
// true

// Create a modified copy without mutating the original using `copy`.
// Only the fields wrapped in `.set(…)` change; the rest are kept as-is.
let renamedJohn = john.copy(name: .set("John \"Coffee\" Doe"))
print(renamedJohn.name)  // John "Coffee" Doe
print(renamedJohn.userId)  // 42 (kept from john)
print(john.name)  // John Doe (john is unchanged)

// =============================================================================
// ENUM TYPES
// =============================================================================

// Skir generates a Swift enum for every enum in the .skir file.
// Every Skir enum has an `.unknown` case added automatically (the default
// value).

let _: [Service_skir.SubscriptionStatus] = [
  .unknownValue,  // default "unknown" value
  .unknown(unrecognized: nil),  // same as the above
  .free,
  .premium,
  .trial(.partial(startTime: Date())),  // wrapper variant carrying a value
]

// =============================================================================
// ENUM MATCHING
// =============================================================================

func describe(_ status: Skir.SubscriptionStatus) -> String {
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

print(describe(john.subscriptionStatus))  // Free user
print(describe(.trial(.partial(startTime: Date()))))  // On trial since ...

// =============================================================================
// SERIALIZATION
// =============================================================================

let serializer = Skir.User.serializer

// Serialize to dense JSON (field-index-based; safe for storage and transport).
// Field names are NOT used, so renaming a field stays backward compatible.
let denseJson = serializer.toJson(john)
print(denseJson)
// [42,"John Doe","Coffee is just...","readable",...]

// Serialize to readable (name-based, indented) JSON.
// Good for debugging; do NOT use for persistent storage.
let readableJson = serializer.toJson(john, readable: true)
print(readableJson)
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
assert(johnFromBytes == john)

// =============================================================================
// PRIMITIVE SERIALIZERS
// =============================================================================

print(Serializers.bool.toJson(true))
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
// "3q2+7w=="

// =============================================================================
// COMPOSITE SERIALIZERS
// =============================================================================

// Optional serializer:
print(Serializers.optional(Serializers.string).toJson("foo"))
// "foo"

print(Serializers.optional(Serializers.string).toJson(nil as String?))
// null

// Array serializer:
print(Serializers.array(Serializers.bool).toJson([true, false]))
// [1,0]

// =============================================================================
// CONSTANTS
// =============================================================================

// Skir generates a typed constant for every `const` in the .skir file.
// Access it via the module namespace or the `Skir` alias:
let tarzan = Service_skir.tarzan  // same as Skir.tarzan
print(tarzan.name)  // Tarzan
print(tarzan.quote)  // AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA

// =============================================================================
// KEYED LISTS
// =============================================================================

// In the .skir file:
//   struct UserRegistry {
//     users: [User|user_id];
//   }
// The '|user_id' suffix tells Skir to index the array by user_id, enabling
// O(1) lookup.
let registry = Service_skir.UserRegistry(users: [john, jane])

// findByKey returns the first element whose user_id matches.
// The index is built lazily on the first call and cached for subsequent calls.
print(registry.users.findByKey(43) != nil)  // true
print(registry.users.findByKey(43)! == jane)  // true

// If no element has the given key, nil is returned.
print(registry.users.findByKey(999) == nil)  // true

// findByKeyOrDefault returns the zero-value element instead of nil.
let notFoundOrDefault = registry.users.findByKeyOrDefault(999)
print(notFoundOrDefault.pets.count)  // 0

// =============================================================================
// REFLECTION
// =============================================================================

// Reflection allows you to inspect a Skir type at runtime.
// Each generated type exposes its schema as a TypeDescriptor via its serializer.
let typeDescriptor = Skir.User.serializer.typeDescriptor

// A TypeDescriptor can be serialized to JSON and deserialized back:
let descriptorFromJson = try! Reflection.TypeDescriptor.parseFromJson(typeDescriptor.asJson())

// Pattern match to distinguish struct, enum, primitive descriptors:
if case .structRecord(let sd) = descriptorFromJson {
  print(sd)  // StructDescriptor(...:User)
}
