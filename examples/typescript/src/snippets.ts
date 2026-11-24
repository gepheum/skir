// Code snippets showing how to use TypeScript-generated data classes.
//
// Run with:
//   npm run snippets

import assert from "assert";
import {
  arraySerializer,
  ByteString,
  optionalSerializer,
  parseTypeDescriptorFromJson,
  primitiveSerializer,
  Timestamp,
} from "skir-client";
import {
  SubscriptionStatus,
  TARZAN,
  User,
  UserHistory,
  UserRegistry,
} from "../skirout/user";

// FROZEN STRUCT CLASSES

// For every struct S in the .skir file, skir generates a frozen (deeply
// immutable) class 'S'  and a mutable class 'S.Mutable'.

// Construct a frozen User with User.create({...})
const john = User.create({
  userId: 42,
  name: "John Doe",
  quote: "Coffee is just a socially acceptable form of rage.",
  pets: [
    {
      name: "Dumbo",
      heightInMeters: 1.0,
      picture: "🐘",
    },
  ],
  subscriptionStatus: "FREE",
  // foo: "bar",
  // ^ Does not compile: 'foo' is not a field of User
});

assert(john.name === "John Doe");

// john.name = "John Smith";
// ^ Does not compile: all the properties are read-only

// With create<"partial">({...}), you don't need to specify all the fields of
// the struct.
const jane = User.create<"partial">({
  userId: 43,
  name: "Jane Doe",
  pets: [{ name: "Fluffy" }, { name: "Fido" }],
});

// Missing fields are initialized to their default values.
assert(jane.quote === "");

const janeHistory = UserHistory.create({
  user: jane,
  // ^ the object you pass to create({...}) can contain struct values
  sessions: [
    {
      login: Timestamp.fromUnixMillis(1234),
      logout: Timestamp.fromUnixMillis(2345),
    },
  ],
});

const defaultUser = User.DEFAULT;
assert(defaultUser.name === "");
// User.DEFAULT is same as User.create<"partial">({});

// MUTABLE STRUCT CLASSES

// User.Mutable is a mutable version of User.
const lylaMut = new User.Mutable();
lylaMut.userId = 44;
lylaMut.name = "Lyla Doe";

// The User.Mutable() constructor also accepts an initializer object.
const jolyMut = new User.Mutable({ userId: 45 });
jolyMut.name = "Joly Doe";

// jolyHistoryMut.user.quote = "I am Joly.";
// ^ Does not compile: quote is readonly because jolyHistoryMut.user might be
// a frozen struct

const jolyHistoryMut = new UserHistory.Mutable();
jolyHistoryMut.user = jolyMut;
// ^ The right-hand side of the assignment can be either frozen or mutable.

// The mutableUser() getter first checks if 'user' is already a mutable struct,
// and if so, returns it. Otherwise, it assigns to 'user' a mutable shallow copy
// of itself and returns it.
jolyHistoryMut.mutableUser.quote = "I am Joly.";

// Similarly, mutablePets() first checks if 'pets' is already a mutable array,
// and if so, returns it. Otherwise, it assigns to 'pets' a mutable shallow copy
// of itself and returns it.
lylaMut.mutablePets.push(User.Pet.create<"partial">({ name: "Cupcake" }));
lylaMut.mutablePets.push(new User.Pet.Mutable({ name: "Simba" }));

// CONVERTING BETWEEN FROZEN AND MUTABLE STRUCTS

// toMutable() does a shallow copy of the frozen struct, so it's cheap. All the
// properties of the copy hold a frozen value.
const evilJaneMut = jane.toMutable();
evilJaneMut.name = "Evil Jane";

// toFrozen() recursively copies the mutable values held by properties of the
// object. It's cheap if all the values are frozen, like in this example.
const evilJane: User = evilJaneMut.toFrozen();

// 'User.OrMutable' is a type alias for 'User | User.Mutable'.
function greet(user: User.OrMutable) {
  console.log(`Hello, ${user.name}`);
}

greet(jane);
// Hello, Jane Doe
greet(lylaMut);
// Hello, Lyla Doe

// MAKING ENUM VALUES

const johnStatus = SubscriptionStatus.FREE;
const janeStatus = SubscriptionStatus.PREMIUM;
const lylaStatus = SubscriptionStatus.create("PREMIUM");
// ^ same as SubscriptionStatus.PREMIUM
const jolyStatus = SubscriptionStatus.UNKNOWN;

// Use create({kind: ..., value: ...}) for wrapper variants.
const roniStatus = SubscriptionStatus.create({
  kind: "trial",
  value: {
    startTime: Timestamp.fromUnixMillis(1234),
  },
});

// CONDITIONS ON ENUMS

// Use 'union.kind' to check which variant the enum value holds.
assert(johnStatus.union.kind === "FREE");

assert(jolyStatus.union.kind === "UNKNOWN");

assert(roniStatus.union.kind === "trial");
// If the enum holds a wrapper variant, you can access the wrapped value through
// 'union.value'.
assert(roniStatus.union.value.startTime.unixMillis === 1234);

function getSubscriptionInfoText(status: SubscriptionStatus): string {
  // Pattern matching on enum variants
  switch (status.union.kind) {
    case "UNKNOWN":
      return "Unknown subscription status";
    case "FREE":
      return "Free user";
    case "PREMIUM":
      return "Premium user";
    case "trial":
      // Here the compiler knows that the type of union.value is
      // SubscriptionStatus.Trial
      return "On trial since " + status.union.value.startTime;
  }
}

// SERIALIZATION

const serializer = User.serializer;

// Serialize 'john' to dense JSON.
const johnDenseJson = serializer.toJson(john);

// With dense JSON, structs are encoded as JSON arrays.
assert(Array.isArray(johnDenseJson));

// toJsonCode() returns a string containing the JSON code.
// Equivalent to calling JSON.stringify() on toJson()'s result.
const johnDenseJsonCode = serializer.toJsonCode(john);
assert(johnDenseJsonCode.startsWith("["));

// Serialize 'john' to readable JSON.
console.log(serializer.toJsonCode(john, "readable"));
// {
//   "user_id": 42,
//   "name": "John Doe",
//   "quote": "Coffee is just a socially acceptable form of rage.",
//   "pets": [
//     {
//       "name": "Dumbo",
//       "height_in_meters": 1,
//       "picture": "🐘"
//     }
//   ],
//   "subscription_status": "FREE"
// }

// The dense JSON flavor is the flavor you should pick if you intend to
// deserialize the value in the future. Skir allows fields to be renamed, and
// because fields names are not part of the dense JSON, renaming a field does
// not prevent you from deserializing the value.
// You should pick the readable flavor mostly for debugging purposes.

// Serialize 'john' to binary format.
const johnBytes = serializer.toBytes(john);

// The binary format is not human readable, but it is slightly more compact than
// JSON, and serialization/deserialization can be a bit faster in languages like
// C++. Only use it when this small performance gain is likely to matter, which
// should be rare.

// Use fromJson(), fromJsonCode() and fromBytes() to deserialize.

const reserializedJohn = serializer.fromJsonCode(johnDenseJsonCode);
assert(reserializedJohn.name === "John Doe");

const reserializedJane = serializer.fromJsonCode(
  serializer.toJsonCode(jane, "readable"),
);
assert(reserializedJane.name === "Jane Doe");

assert(serializer.fromJson(johnDenseJson).name === "John Doe");
assert(serializer.fromBytes(johnBytes.toBuffer()).name === "John Doe");

// PRIMITIVE SERIALIZERS

assert(primitiveSerializer("bool").toJson(true) === 1);
assert(primitiveSerializer("int32").toJson(3) === 3);
assert(
  primitiveSerializer("int64").toJson(BigInt("9223372036854775807")) ===
    "9223372036854775807",
);
assert(
  primitiveSerializer("hash64").toJson(BigInt("18446744073709551615")) ===
    "18446744073709551615",
);
assert(
  primitiveSerializer("timestamp").toJson(
    Timestamp.fromUnixMillis(1743682787000),
  ) === 1743682787000,
);
assert(primitiveSerializer("float32").toJson(3.14) === 3.14);
assert(primitiveSerializer("float64").toJson(3.14) === 3.14);
assert(primitiveSerializer("string").toJson("Foo") === "Foo");
assert(
  primitiveSerializer("bytes").toJson(
    ByteString.sliceOf(new Uint8Array([1, 2, 3]).buffer),
  ) === "AQID",
);

// COMPOSITE SERIALIZERS

assert(
  optionalSerializer(primitiveSerializer("string")).toJson("foo") === "foo",
);
assert(optionalSerializer(primitiveSerializer("string")).toJson(null) === null);

console.log(arraySerializer(primitiveSerializer("bool")).toJson([true, false]));
// [1, 0]

// FROZEN ARRAYS AND COPIES

const pets = [
  User.Pet.create<"partial">({ name: "Fluffy" }),
  User.Pet.create<"partial">({ name: "Fido" }),
];

const jade = User.create<"partial">({
  pets: pets,
  // ^ makes a copy of 'pets' because 'pets' is mutable
});

// jade.pets.push(...)
// ^ Compile-time error: pets is readonly

assert(jade.pets !== pets);

const jack = User.create<"partial">({
  pets: jade.pets,
  // ^ doesn't make a copy because 'jade.pets' is frozen
});

assert(jack.pets === jade.pets);

// KEYED ARRAYS

const userRegistry = UserRegistry.create({
  users: [john, jane, lylaMut, evilJane],
});

// searchUsers() returns the user with the given key (specified in the .skir
// file). In this example, the key is the user id.
// The first lookup runs in O(N) time, and the following lookups run in O(1)
// time.
assert(userRegistry.searchUsers(42) === john);
assert(userRegistry.searchUsers(100) === undefined);

// If multiple elements have the same key, the search method returns the last
// one. Duplicates are allowed but generally discouraged.
assert(userRegistry.searchUsers(43) === evilJane);

// CONSTANTS

console.log(TARZAN);
// User {
//   userId: 123,
//   name: 'Tarzan',
//   quote: 'AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA',
//   pets: [ User_Pet { name: 'Cheeta', heightInMeters: 1.67, picture: '🐒' } ],
//   subscriptionStatus: SubscriptionStatus {
//     kind: 'trial',
//     value: SubscriptionStatus_Trial { startTime: [Timestamp] }
//   }
// }

// REFLECTION

// Reflection allows you to inspect a skir type at runtime.

const fieldNames: string[] = [];
for (const field of User.serializer.typeDescriptor.fields) {
  const { name, number, property, type } = field;
  fieldNames.push(name);
}
console.log(fieldNames);
// [ 'user_id', 'name', 'quote', 'pets', 'subscription_status' ]

// A type descriptor can be serialized to JSON and deserialized later.
const typeDescriptor = parseTypeDescriptorFromJson(
  User.serializer.typeDescriptor.asJson(),
);
