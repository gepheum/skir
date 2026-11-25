// Code snippets showing how to use Dart-generated data classes.
//
// Run with:
//   dart run bin/snippets.dart

import 'dart:typed_data';

import 'package:skir_client/skir_client.dart' as skir;
import 'package:skir_dart_example/all_strings_to_upper_case.dart';
import 'package:skir_dart_example/skirout/user.dart';

// ignore_for_file: unused_local_variable
// ignore_for_file: unused_element

void main() {
  // ===========================================================================
  // FROZEN STRUCT CLASSES
  // ===========================================================================

  // For every struct S in the .skir file, skir generates a frozen (deeply
  // immutable) class 'S' and a mutable class 'S_mutable'.

  // Construct a frozen User.
  final john = User(
    // All fields are required.
    userId: 42,
    name: "John Doe",
    quote: "Coffee is just a socially acceptable form of rage.",
    pets: [
      User_Pet(
        name: "Dumbo",
        heightInMeters: 1.0,
        picture: "🐘",
      ),
    ],
    subscriptionStatus: SubscriptionStatus.free,
    // foo: "bar",
    // ^ Does not compile: 'foo' is not a field of User
  );

  assert(john.name == "John Doe");

  // john.name = "John Smith";
  // ^ Does not compile: all the properties are read-only

  // You can also construct a frozen User using the builder pattern with a
  // mutable instance as the builder.
  final User jane = (User.mutable()
        ..userId = 43
        ..name = "Jane Doe"
        ..pets = [
          User_Pet(name: "Fluffy", heightInMeters: 0.2, picture: "🐱"),
          User_Pet.mutable()
            ..name = "Fido"
            ..heightInMeters = 0.25
            ..picture = "🐶"
            ..toFrozen(),
        ])
      .toFrozen();

  // Fields not explicitly set are initialized to their default values.
  assert(jane.quote == "");

  // User.defaultInstance is an instance of User with all fields set to their
  // default values.
  assert(User.defaultInstance.name == "");
  assert(User.defaultInstance.pets.isEmpty);

  // ===========================================================================
  // MUTABLE STRUCT CLASSES
  // ===========================================================================

  // 'User_mutable' is a dataclass similar to User except it is mutable.
  // Use User.mutable() to create a new instance.
  final User_mutable mutableLyla = User.mutable()..userId = 44;
  mutableLyla.name = "Lyla Doe";

  final UserHistory_mutable userHistory = UserHistory.mutable();
  userHistory.user = mutableLyla;
  // ^ The right-hand side of the assignment can be either frozen or mutable.

  // The 'mutableUser' getter provides access to a mutable version of 'user'.
  // If 'user' is already mutable, it returns it directly.
  // If 'user' is frozen, it creates a mutable shallow copy, assigns it to
  // 'user', and returns it.

  // The user is currently 'mutableLyla', which is mutable.
  assert(identical(userHistory.mutableUser, mutableLyla));
  // Now assign a frozen User to 'user'.
  userHistory.user = john;
  // Since 'john' is frozen, mutableUser makes a mutable shallow copy of it.
  assert(!identical(userHistory.mutableUser, john));
  userHistory.mutableUser.name = "John the Second";
  assert(userHistory.user.name == "John the Second");
  assert(userHistory.user.userId == 42);

  // Similarly, 'mutablePets' provides access to a mutable version of 'pets'.
  // It returns the existing list if already mutable, or creates and returns a
  // mutable shallow copy.
  mutableLyla.mutablePets.add(User_Pet(
    name: "Simba",
    heightInMeters: 0.4,
    picture: "🦁",
  ));
  mutableLyla.mutablePets.add(User_Pet.mutable()..name = "Cupcake");

  // ===========================================================================
  // CONVERTING BETWEEN FROZEN AND MUTABLE STRUCTS
  // ===========================================================================

  // toMutable() does a shallow copy of the frozen struct, so it's cheap. All
  // the properties of the copy hold a frozen value.
  final evilJane = (jane.toMutable()
        ..name = "Evil Jane"
        ..quote = "I solemnly swear I am up to no good.")
      .toFrozen();

  assert(evilJane.name == "Evil Jane");
  assert(evilJane.userId == 43);

  // 'User_orMutable' is a type alias for the sealed class that both 'User' and
  // 'User_mutable' implement.
  void greet(User_orMutable user) {
    print("Hello, ${user.name}");
  }

  greet(jane);
  // Hello, Jane Doe
  greet(mutableLyla);
  // Hello, Lyla Doe

  // ===========================================================================
  // MAKING ENUM VALUES
  // ===========================================================================

  final johnStatus = SubscriptionStatus.free;
  final janeStatus = SubscriptionStatus.premium;

  final jolyStatus = SubscriptionStatus.unknown;

  // Use wrapX() or createX() for wrapper fields:
  //   - wrapX() expects the value to wrap.
  //   - createX() creates a new struct with the given params and wraps it

  final roniStatus = SubscriptionStatus.wrapTrial(
    SubscriptionStatus_Trial(
        startTime: DateTime.fromMillisecondsSinceEpoch(1234, isUtc: true)),
  );

  // More concisely, with createX():
  final ericStatus = SubscriptionStatus.createTrial(
    startTime: DateTime.fromMillisecondsSinceEpoch(5678, isUtc: true),
  );

  // ===========================================================================
  // CONDITIONS ON ENUMS
  // ===========================================================================

  assert(johnStatus == SubscriptionStatus.free);
  assert(janeStatus == SubscriptionStatus.premium);
  assert(jolyStatus == SubscriptionStatus.unknown);

  if (roniStatus is SubscriptionStatus_trialWrapper) {
    assert(roniStatus.value.startTime.millisecondsSinceEpoch == 1234);
  } else {
    throw AssertionError();
  }

  String getSubscriptionInfoText(SubscriptionStatus status) {
    // Use pattern matching for typesafe switches on enums.
    return switch (status) {
      SubscriptionStatus_unknown() => "Unknown subscription status",
      SubscriptionStatus.free => "Free user",
      SubscriptionStatus.premium => "Premium user",
      SubscriptionStatus_trialWrapper(:final value) =>
        "On trial since ${value.startTime}",
    };
  }

  // ===========================================================================
  // SERIALIZATION
  // ===========================================================================

  final serializer = User.serializer;

  // Serialize 'john' to dense JSON.
  final String johnDenseJson = serializer.toJsonCode(john);
  print(johnDenseJson);
  // [42,"John Doe",...]

  // Serialize 'john' to readable JSON.
  print(serializer.toJsonCode(john, readableFlavor: true));
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
  // deserialize the value in the future. Skir allows fields to be renamed, and
  // because field names are not part of the dense JSON, renaming a field does
  // not prevent you from deserializing the value.
  // You should pick the readable flavor mostly for debugging purposes.

  // Serialize 'john' to binary format.
  final Uint8List johnBytes = serializer.toBytes(john);

  // The binary format is not human readable, but it is slightly more compact
  // than JSON, and serialization/deserialization can be a bit faster in
  // languages like C++. Only use it when this small performance gain is likely
  // to matter, which should be rare.

  // Use fromJson(), fromJsonCode() and fromBytes() to deserialize.

  final reserializedJohn = serializer.fromJsonCode(johnDenseJson);
  assert(reserializedJohn.name == "John Doe");

  final reserializedJane = serializer.fromJsonCode(
    serializer.toJsonCode(jane, readableFlavor: true),
  );
  assert(reserializedJane.name == "Jane Doe");

  assert(serializer.fromBytes(johnBytes) == john);

  // ===========================================================================
  // PRIMITIVE SERIALIZERS
  // ===========================================================================

  assert(skir.Serializers.bool.toJson(true) == 1);
  assert(skir.Serializers.int32.toJson(3) == 3);
  assert(skir.Serializers.int64.toJson(9223372036854775807) ==
      "9223372036854775807");
  assert(skir.Serializers.hash64.toJson(BigInt.parse("18446744073709551615")) ==
      "18446744073709551615");
  assert(skir.Serializers.timestamp
          .toJson(DateTime.fromMillisecondsSinceEpoch(1743682787000)) ==
      1743682787000);
  assert(skir.Serializers.float32.toJson(3.14) == 3.14);
  assert(skir.Serializers.float64.toJson(3.14) == 3.14);
  assert(skir.Serializers.string.toJson("Foo") == "Foo");
  assert(
      skir.Serializers.bytes.toJson(skir.ByteString.copy([1, 2, 3])) == "AQID");

  // ===========================================================================
  // COMPOSITE SERIALIZERS
  // ===========================================================================

  assert(skir.Serializers.optional(skir.Serializers.string).toJson("foo") ==
      "foo");
  assert(
      skir.Serializers.optional(skir.Serializers.string).toJson(null) == null);

  print(skir.Serializers.iterable(skir.Serializers.bool).toJson([true, false]));
  // [1, 0]

  // ===========================================================================
  // FROZEN LISTS AND COPIES
  // ===========================================================================

  final pets = [
    User_Pet(name: "Fluffy", heightInMeters: 0.25, picture: "🐶"),
    User_Pet(name: "Fido", heightInMeters: 0.5, picture: "🐻"),
  ];

  final jade = User(
    userId: 46,
    name: "Jade",
    quote: "",
    pets: pets,
    // ^ makes a copy of 'pets' because 'pets' is mutable
    subscriptionStatus: SubscriptionStatus.unknown,
  );

  // jade.pets.add(...)
  // ^ Compile-time error: pets is a frozen list

  assert(!identical(jade.pets, pets));

  final jack = User(
    userId: 47,
    name: "Jack",
    quote: "",
    pets: jade.pets,
    // ^ doesn't make a copy because 'jade.pets' is frozen
    subscriptionStatus: SubscriptionStatus.unknown,
  );

  assert(identical(jack.pets, jade.pets));

  // ===========================================================================
  // KEYED LISTS
  // ===========================================================================

  final userRegistry = UserRegistry(
    users: [john, jane, mutableLyla, evilJane],
  );

  // find() returns the user with the given key (specified in the .skir file).
  // In this example, the key is the user id.
  // The first lookup runs in O(N) time, and the following lookups run in O(1)
  // time.
  assert(userRegistry.users.findByKey(42) == john);
  assert(userRegistry.users.findByKey(100) == null);

  // If multiple elements have the same key, find() returns the last one.
  // Duplicates are allowed but generally discouraged.
  assert(userRegistry.users.findByKey(43) == evilJane);

  // ===========================================================================
  // CONSTANTS
  // ===========================================================================

  print(tarzan);
  // User(
  //   userId: 123,
  //   name: "Tarzan",
  //   quote: "AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA",
  //   pets: [
  //     User_Pet(
  //       name: "Cheeta",
  //       heightInMeters: 1.67,
  //       picture: "🐒",
  //     ),
  //   ],
  //   subscriptionStatus: SubscriptionStatus.wrapTrial(
  //     SubscriptionStatus_Trial(
  //       startTime: DateTime.fromMillisecondsSinceEpoch(
  //         // 2025-04-02T11:13:29.000Z
  //         1743592409000
  //       ),
  //     )
  //   ),
  // )

  // ===========================================================================
  // REFLECTION
  // ===========================================================================

  // Reflection allows you to inspect a skir type at runtime.

  final fieldNames = <String>[];
  for (final field in User.serializer.typeDescriptor.fields) {
    fieldNames.add(field.name);
  }
  print(fieldNames);
  // [user_id, name, quote, pets, subscription_status]

  // A type descriptor can be serialized to JSON and deserialized later.
  final typeDescriptor = skir.TypeDescriptor.parseFromJson(
    User.serializer.typeDescriptor.asJson,
  );
  print("Type descriptor deserialized successfully");

  // The 'allStringsToUpperCase' function uses reflection to convert all the
  // strings contained in a given Skir value to upper case.
  // See the implementation at
  // https://github.com/gepheum/skir-dart-example/blob/main/lib/all_strings_to_upper_case.dart
  print(allStringsToUpperCase<User>(tarzan, User.serializer.typeDescriptor));
  // User(
  //   userId: 123,
  //   name: "TARZAN",
  //   quote: "AAAAAAAAAAYAAAAAAAAAAYAAAAAAAAAA",
  //   pets: [
  //     User_Pet(
  //       name: "CHEETA",
  //       heightInMeters: 1.67,
  //       picture: "🐒",
  //     ),
  //   ],
  //   subscriptionStatus: SubscriptionStatus.wrapTrial(
  //     SubscriptionStatus_Trial(
  //       startTime: DateTime.fromMillisecondsSinceEpoch(
  //         // 2025-04-02T11:13:29.000Z
  //         1743592409000
  //       ),
  //     )
  //   ),
  // )
}
