// Code snippets showing how to use Gleam-generated data types.
//
// Run with: gleam run -m snippets

import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import skir_client
import skir_client/timestamp
import skir_client/type_descriptor
import skirout/user

pub fn main() {
  // ==========================================================================
  // STRUCT TYPES
  // ==========================================================================

  // Skir generates a plain Gleam record for every struct in the .skir file.
  // Construct one using the generated `*_new()` helper, which sets the
  // `unrecognized_` field automatically.
  let john =
    user.user_new(
      name: "John Doe",
      pets: [
        user.user__pet_new(height_in_meters: 1.0, name: "Dumbo", picture: "🐘"),
      ],
      quote: "Coffee is just a socially acceptable form of rage.",
      subscription_status: user.SubscriptionStatusFree,
      user_id: 42,
    )

  io.println(john.name)
  // John Doe

  // `user_default` holds the default value with every field at its zero value.
  io.println(user.user_default.name)
  // (empty string)
  io.println(int.to_string(user.user_default.user_id))
  // 0

  // Combining the _default constant with Gleam's record update syntax allows
  // you to instantiate a struct by only specifying a subset of its fields;
  // the remaining fields are set to their default values.
  let jane = user.User(..user.user_default, user_id: 43, name: "Jane Doe")

  io.println(jane.quote)
  // (empty string)
  io.println(int.to_string(list.length(jane.pets)))
  // 0

  // Gleam records are immutable.
  // To make a modified copy, use record update syntax on the original.
  let evil_john =
    user.User(
      ..john,
      name: "Evil John",
      quote: "I solemnly swear I am up to no good.",
    )

  io.println(evil_john.name)
  // Evil John
  io.println(int.to_string(evil_john.user_id))
  // 42 (copied from john)

  // ==========================================================================
  // ENUM TYPES
  // ==========================================================================

  // Skir generates a Gleam custom type for every enum in the .skir file.
  // The Unknown variant is added automatically and is the default.
  let _statuses = [
    // Unknown is the default and is present in all Skir enums.
    user.subscription_status_unknown,
    user.SubscriptionStatusFree,
    user.SubscriptionStatusPremium,
    // Wrapper variants carry an inner struct.
    user.SubscriptionStatusTrialX(
      user.subscription_status__trial_new(start_time: timestamp.Timestamp(
        unix_millis: 1_743_592_409_000,
      )),
    ),
  ]

  // ==========================================================================
  // ENUM MATCHING
  // ==========================================================================

  let get_info_text = fn(status: user.SubscriptionStatus) -> String {
    case status {
      user.SubscriptionStatusFree -> "Free user"
      user.SubscriptionStatusPremium -> "Premium user"
      user.SubscriptionStatusTrialX(t) ->
        "On trial since " <> int.to_string(t.start_time.unix_millis)
      user.SubscriptionStatusUnknown(_) -> "Unknown subscription status"
    }
  }

  io.println(get_info_text(john.subscription_status))
  // Free user

  let trial_status =
    user.SubscriptionStatusTrialX(
      user.subscription_status__trial_new(start_time: timestamp.Timestamp(
        unix_millis: 1_743_592_409_000,
      )),
    )
  io.println(get_info_text(trial_status))
  // On trial since 1743592409000

  // ==========================================================================
  // SERIALIZATION
  // ==========================================================================

  let serializer = user.user_serializer()

  // Serialize to dense JSON (field-number-based; the default mode).
  // Use this when you plan to deserialize the value later. Because field
  // names are not included, renaming a field remains backward-compatible.
  let john_dense_json = skir_client.to_dense_json_code(serializer, john)
  io.println(john_dense_json)
  // [42,"John Doe",...]

  // Serialize to readable (name-based, indented) JSON.
  // Use this mainly for debugging.
  io.println(skir_client.to_readable_json_code(serializer, john))
  // {
  //   "user_id": 42,
  //   "name": "John Doe",
  //   "quote": "Coffee is just a socially acceptable form of rage.",
  //   "pets": [ ... ],
  //   "subscription_status": "FREE"
  // }

  // Deserialize from JSON (both dense and readable formats are accepted).
  let assert Ok(reserialized_john) =
    skir_client.from_json_code(serializer, john_dense_json)
  let assert True = reserialized_john == john

  // Serialize to binary format (more compact than JSON; useful when
  // performance matters, though the difference is rarely significant).
  let john_bytes = skir_client.to_bytes(serializer, john)
  let assert Ok(from_bytes) = skir_client.from_bytes(serializer, john_bytes)
  let assert True = from_bytes == john

  // ==========================================================================
  // PRIMITIVE SERIALIZERS
  // ==========================================================================

  io.println(skir_client.to_dense_json_code(skir_client.bool_serializer(), True))
  // 1
  io.println(skir_client.to_dense_json_code(skir_client.int32_serializer(), 3))
  // 3
  io.println(skir_client.to_dense_json_code(
    skir_client.int64_serializer(),
    9_223_372_036_854_775_807,
  ))
  // "9223372036854775807"
  io.println(skir_client.to_dense_json_code(
    skir_client.float32_serializer(),
    1.5,
  ))
  // 1.5
  io.println(skir_client.to_dense_json_code(
    skir_client.float64_serializer(),
    1.5,
  ))
  // 1.5
  io.println(skir_client.to_dense_json_code(
    skir_client.string_serializer(),
    "Foo",
  ))
  // "Foo"
  io.println(skir_client.to_dense_json_code(
    skir_client.timestamp_serializer(),
    timestamp.Timestamp(unix_millis: 1_743_682_787_000),
  ))
  // 1743682787000

  // ==========================================================================
  // COMPOSITE SERIALIZERS
  // ==========================================================================

  // Optional serializer:
  io.println(skir_client.to_dense_json_code(
    skir_client.optional_serializer(skir_client.string_serializer()),
    option.Some("foo"),
  ))
  // "foo"

  io.println(skir_client.to_dense_json_code(
    skir_client.optional_serializer(skir_client.string_serializer()),
    option.None,
  ))
  // null

  // List serializer:
  io.println(
    skir_client.to_dense_json_code(
      skir_client.list_serializer(skir_client.bool_serializer()),
      [True, False],
    ),
  )
  // [1,0]

  // ==========================================================================
  // CONSTANTS
  // ==========================================================================

  // Constants declared with 'const' in the .skir file are available as
  // top-level constants in the generated Gleam code.
  io.println(skir_client.to_readable_json_code(
    user.user_serializer(),
    user.tarzan_const,
  ))
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

  // ==========================================================================
  // REFLECTION
  // ==========================================================================

  // Reflection allows you to inspect a Skir type at runtime.

  let td = skir_client.type_descriptor(user.user_serializer())

  // Print the full type descriptor as JSON.
  io.println(type_descriptor.type_descriptor_to_json(td))
  // {
  //   "type": { "kind": "record", "value": "user.skir:User" },
  //   "records": [ ... ]
  // }

  // Pattern match on the records map to inspect the User struct's fields.
  let assert Ok(type_descriptor.StructRecord(user_struct)) =
    dict.get(td.records, "user.skir:User")

  let field_names = list.map(user_struct.fields, fn(f) { f.name })
  io.println(string.join(field_names, ", "))
  // user_id, name, quote, pets, subscription_status

  io.println(int.to_string(list.length(user_struct.fields)))
  // 5

  // A TypeDescriptor can be serialized to JSON and parsed back.
  let type_descriptor_json = type_descriptor.type_descriptor_to_json(td)
  let assert Ok(reparsed_td) =
    type_descriptor.type_descriptor_from_json(type_descriptor_json)
  let assert True = reparsed_td == td
}
