import { CodeBlock, H1, H2, H3, H4, InlineCode, P, Prose } from '@/components/prose'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Gleam - Skir Documentation',
  description: 'Learn how to use Skir-generated Gleam code in your projects',
}

export default function GleamPage() {
  return (
    <Prose>
      <H1>Gleam</H1>
      <P>This guide explains how to use Skir in a Gleam project.</P>

      <H2>Set up</H2>
      <P>
        In your <InlineCode>skir.yml</InlineCode> file, add the following snippet under{' '}
        <InlineCode>generators</InlineCode>:
      </P>
      <CodeBlock language="yaml">{`- mod: skir-gleam-gen
  outDir: ./src/skirout
  config: {}`}</CodeBlock>

      <P>
        Or if you prefer not to place <InlineCode>skirout</InlineCode> directly under{' '}
        <InlineCode>src</InlineCode>:
      </P>
      <CodeBlock language="yaml">{`- mod: skir-gleam-gen
  outDir: ./src/generated/skirout
  config:
    importPathToSkirout: generated/skirout`}</CodeBlock>

      <P>
        The generated Gleam code has a runtime dependency on <InlineCode>skir_client</InlineCode>.
        Add it to your project with:
      </P>
      <CodeBlock language="bash">{`gleam add skir_client`}</CodeBlock>

      <P>
        For more information, see this Gleam project{' '}
        <a
          href="https://github.com/gepheum/skir-gleam-example"
          target="_blank"
          rel="noopener noreferrer"
        >
          example
        </a>
        .
      </P>

      <H2>Gleam generated code guide</H2>
      <P>
        The examples below are for the code generated from{' '}
        <a
          href="https://github.com/gepheum/skir-gleam-example/blob/main/skir-src/user.skir"
          target="_blank"
          rel="noopener noreferrer"
        >
          this
        </a>{' '}
        .skir file.
      </P>

      <H3>Referring to generated symbols</H3>
      <CodeBlock language="swift" filename="Gleam">{`// Import the module generated from "user.skir"
import skirout/user

// Now you can use: user.User, user.SubscriptionStatus, user.tarzan_const, etc.`}</CodeBlock>

      <H3>Struct types</H3>
      <P>Skir generates a plain Gleam record for every struct in the .skir file.</P>
      <CodeBlock language="swift" filename="Gleam">{`import skir_client
import skir_client/timestamp
import skirout/user

// Construct a User using the generated helper function.
// The helper sets the \`unrecognized_\` field automatically.
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

// \`user_default\` holds the default value with every field at its zero value.
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
// 0`}</CodeBlock>

      <H4>Creating modified copies</H4>
      <CodeBlock language="swift" filename="Gleam">{`// Gleam records are immutable.
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
// 42 (copied from john)`}</CodeBlock>

      <H3>Enum types</H3>
      <P>The definition of the SubscriptionStatus enum in the .skir file is:</P>
      <CodeBlock language="rust" filename="Skir">{`enum SubscriptionStatus {
  free;
  trial: Trial;
  premium;
}`}</CodeBlock>
      <P>Skir generates a Gleam custom type for every enum in the .skir file.</P>

      <H4>Constructing enum values</H4>
      <CodeBlock language="swift" filename="Gleam">{`let _statuses = [
  // Unknown is the default and is present in all Skir enums.
  user.subscription_status_unknown,
  user.SubscriptionStatusFree,
  user.SubscriptionStatusPremium,
  // Wrapper variants carry an inner struct.
  user.SubscriptionStatusTrialX(
    user.subscription_status__trial_new(
      start_time: timestamp.Timestamp(unix_millis: 1_743_592_409_000),
    ),
  ),
]`}</CodeBlock>

      <H4>Pattern matching on enums</H4>
      <CodeBlock
        language="swift"
        filename="Gleam"
      >{`let get_info_text = fn(status: user.SubscriptionStatus) -> String {
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
    user.subscription_status__trial_new(
      start_time: timestamp.Timestamp(unix_millis: 1_743_592_409_000),
    ),
  )
io.println(get_info_text(trial_status))
// On trial since 1743592409000`}</CodeBlock>

      <H3>Serialization</H3>
      <P>
        The serializer for a type is returned by calling the generated{' '}
        <InlineCode>*_serializer()</InlineCode> function. Use functions from{' '}
        <InlineCode>skir_client</InlineCode> to serialize and deserialize values.
      </P>
      <CodeBlock language="swift" filename="Gleam">{`let serializer = user.user_serializer()

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
//   "subscription_status": "free"
// }

// Deserialize from JSON (both dense and readable formats are accepted).
let assert Ok(reserialized_john) =
  skir_client.from_json_code(serializer, john_dense_json)
let assert True = reserialized_john == john

// Serialize to binary format (more compact than JSON; useful when
// performance matters, though the difference is rarely significant).
let john_bytes = skir_client.to_bytes(serializer, john)
let assert Ok(from_bytes) = skir_client.from_bytes(serializer, john_bytes)
let assert True = from_bytes == john`}</CodeBlock>

      <H3>Primitive serializers</H3>
      <CodeBlock
        language="swift"
        filename="Gleam"
      >{`io.println(skir_client.to_dense_json_code(skir_client.bool_serializer(), True))
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
// 1743682787000`}</CodeBlock>

      <H3>Composite serializers</H3>
      <CodeBlock language="swift" filename="Gleam">{`// Optional serializer:
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
// [1,0]`}</CodeBlock>

      <H3>Constants</H3>
      <CodeBlock
        language="swift"
        filename="Gleam"
      >{`// Constants declared with 'const' in the .skir file are available as
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
// }`}</CodeBlock>

      <H3>SkirRPC services</H3>
      <P>
        <strong>Starting a SkirRPC service on an HTTP server</strong> - full example{' '}
        <a
          href="https://github.com/gepheum/skir-gleam-example/blob/main/src/start_service.gleam"
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
          href="https://github.com/gepheum/skir-gleam-example/blob/main/src/call_service.gleam"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>

      <H3>Reflection</H3>
      <P>Reflection allows you to inspect a Skir type at runtime.</P>
      <CodeBlock language="swift" filename="Gleam">{`import gleam/dict
import gleam/list
import skir_client
import skir_client/type_descriptor

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
let assert True = reparsed_td == td`}</CodeBlock>
    </Prose>
  )
}
