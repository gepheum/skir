import { CodeBlock, H1, H2, H3, H4, InlineCode, P, Prose } from '@/components/prose'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'MoonBit - Skir Documentation',
  description: 'Learn how to use Skir-generated MoonBit code in your projects',
}

export default function MoonBitPage() {
  return (
    <Prose>
      <H1>Skir&apos;s MoonBit code generator</H1>
      <P>
        Official plugin for generating MoonBit code from{' '}
        <a href="https://github.com/gepheum/skir" target="_blank" rel="noopener noreferrer">
          .skir
        </a>{' '}
        files.
      </P>

      <H2>Set up</H2>
      <P>
        In your <InlineCode>skir.yml</InlineCode> file, add the following snippet under{' '}
        <InlineCode>generators</InlineCode>:
      </P>
      <CodeBlock language="yaml">{`- mod: skir-moonbit-gen
  outDir: ./skirout
  config: {}`}</CodeBlock>
      <P>
        The generated MoonBit code has a runtime dependency on{' '}
        <InlineCode>gepheum/skir-client</InlineCode>. Add it with:
      </P>
      <CodeBlock language="bash">{`moon add gepheum/skir-client`}</CodeBlock>
      <P>
        For more information, see this MoonBit project{' '}
        <a
          href="https://github.com/gepheum/skir-moonbit-example"
          target="_blank"
          rel="noopener noreferrer"
        >
          example
        </a>
        .
      </P>

      <H2>MoonBit generated code guide</H2>
      <P>
        The examples below are for the code generated from{' '}
        <a
          href="https://github.com/gepheum/skir-moonbit-example/blob/main/skir-src/user.skir"
          target="_blank"
          rel="noopener noreferrer"
        >
          this
        </a>{' '}
        .skir file. Most code snippets are quoted from{' '}
        <a
          href="https://github.com/gepheum/skir-moonbit-example/blob/main/src/snippets.mbt"
          target="_blank"
          rel="noopener noreferrer"
        >
          moonbit-example/src/snippets.mbt
        </a>
        .
      </P>

      <H3>Struct types</H3>
      <P>Skir generates a plain MoonBit struct for each struct in the .skir schema.</P>
      <CodeBlock language="moonbit">{`let john = @skirout_user.User::new(
  user_id=42,
  name="John Doe",
  quote="Coffee is just a socially acceptable form of rage.",
  pets=@client.ImmutVector::from_array([
    @skirout_user.User_Pet::new(
      name="Dumbo",
      height_in_meters=1.0,
      picture="🐘",
    ),
  ]),
  subscription_status=@skirout_user.SubscriptionStatus::free(),
)

println(john.name)
// John Doe

let evil_john = john.copy(
  name=@client.KeepOrSet::Set("Evil John"),
  quote=@client.KeepOrSet::Set("I solemnly swear I am up to no good."),
)

println(evil_john.name)
// Evil John
println(evil_john.user_id.to_string())
// 42

let jane = @skirout_user.User::default().copy(
  user_id=@client.KeepOrSet::Set(43),
  name=@client.KeepOrSet::Set("Jane Doe"),
)

println(jane.name)
// Jane Doe
println(jane.quote)
// (empty string)`}</CodeBlock>

      <H3>Enum types</H3>
      <CodeBlock language="moonbit">{`let trial_payload = @skirout_user.SubscriptionStatus_Trial::new(
  start_time=@client.Timestamp::from_unix_millis(1744974198000L),
)

let some_statuses = [
  @skirout_user.SubscriptionStatus::unknown(),
  @skirout_user.SubscriptionStatus::free(),
  @skirout_user.SubscriptionStatus::premium(),
  @skirout_user.SubscriptionStatus::trial(trial_payload),
]

println(some_statuses.length().to_string())
// 4`}</CodeBlock>

      <H3>Conditions on enums</H3>
      <CodeBlock language="moonbit">{`let subscription_info_text = fn(
  status : @skirout_user.SubscriptionStatus,
) {
  match status {
    Unknown(_) => "Unknown subscription status"
    Free => "Free user"
    Trial(trial) => "On trial since " + trial.start_time.to_iso8601()
    Premium => "Premium user"
  }
}

println(subscription_info_text(john.subscription_status))
// Free user

println(
  subscription_info_text(@skirout_user.SubscriptionStatus::unknown()),
)
// Unknown subscription status`}</CodeBlock>

      <H3>Serialization</H3>
      <P>Every generated struct and enum has a static serializer.</P>
      <CodeBlock language="moonbit">{`let user_serializer = @skirout_user.User::serializer()

let john_dense_json = user_serializer.to_dense_json_code(john)
println(john_dense_json)
// [42,"John Doe",...]

let john_readable_json = user_serializer
  .to_readable_json(john)
  .stringify(indent=2)
println(john_readable_json)
// {
//   "user_id": 42,
//   ...
// }

let john_binary = user_serializer.to_bytes(john)`}</CodeBlock>

      <H3>Deserialization</H3>
      <CodeBlock language="moonbit">{`let from_dense = match user_serializer.from_json_code(john_dense_json) {
  Ok(value) => value
  Err(_) => panic()
}

let from_readable = match user_serializer.from_json_code(john_readable_json) {
  Ok(value) => value
  Err(_) => panic()
}

let from_binary = match
  user_serializer.from_bytes(
    john_binary,
    unrecognized_values=@client.UnrecognizedValues::Drop,
  ) {
  Ok(value) => value
  Err(_) => panic()
}

if from_dense != john || from_readable != john || from_binary != john {
  panic()
}`}</CodeBlock>

      <H3>Primitive serializers</H3>
      <CodeBlock language="moonbit">{`println(@client.bool_serializer().to_dense_json_code(true))
// 1
println(@client.int32_serializer().to_dense_json_code(3))
// 3
println(@client.int64_serializer().to_dense_json_code(9223372036854775807L))
// "9223372036854775807"
println(
  @client.hash64_serializer().to_dense_json_code(18446744073709551615UL),
)
// "18446744073709551615"
println(@client.float32_serializer().to_dense_json_code(3.14))
// 3.14
println(@client.float64_serializer().to_dense_json_code(3.14))
// 3.14
println(@client.string_serializer().to_dense_json_code("Foo"))
// "Foo"
println(@client.bytes_serializer().to_dense_json_code(@utf8.encode("ABC")))
// "QUJD"`}</CodeBlock>

      <H3>Composite serializers</H3>
      <CodeBlock language="moonbit">{`let opt_string_ser = @client.optional_serializer(@client.string_serializer())
println(opt_string_ser.to_dense_json_code(None))
// null
println(opt_string_ser.to_dense_json_code(Some("foo")))
// "foo"

let bool_array_ser = @client.vector_serializer(@client.bool_serializer())
println(
  bool_array_ser.to_dense_json_code(
    @client.ImmutVector::from_array([true, false]),
  ),
)
// [1,0]`}</CodeBlock>

      <H3>Constants</H3>
      <CodeBlock language="moonbit">{`let tarzan = @skirout_user.tarzan_const
println(tarzan.name)
// Tarzan
println(user_serializer.to_readable_json(tarzan).stringify(indent=2))
// {
//   "user_id": 123,
//   ...
// }`}</CodeBlock>

      <H3>Keyed arrays</H3>
      <CodeBlock language="moonbit">{`let user_registry = @skirout_user.UserRegistry::new(
  users=@skirout_user.User_byUserId::from_array([john, jane, evil_john]),
)

let found = user_registry.users.find_by_user_id(43)
match found {
  Some(user) => println(user.name)
  None => panic()
}
// Jane Doe

let not_found = user_registry.users.find_by_user_id(999)
println((not_found is None).to_string())
// true

let found_or_default = user_registry.users.find_by_user_id_or_default(999)
println(found_or_default.pets.length().to_string())
// 0`}</CodeBlock>

      <H3>Reflection</H3>
      <CodeBlock language="moonbit">{`let user_td = user_serializer.type_descriptor()
println(user_td.records.length().to_string())

for record in user_td.records.iter() {
  match record {
    Struct(sd) =>
      if sd.record_id == "user.skir:User" {
        println(sd.record_id + " has " + sd.fields.length().to_string() + " fields")
      }
    Enum(_) => ()
  }
}

let user_td_json = user_td.as_json()
let parsed_td = match @client.parse_from_json(user_td_json) {
  Ok(v) => v
  Err(_) => panic()
}
println(parsed_td.records.length().to_string())`}</CodeBlock>

      <H3>SkirRPC services</H3>
      <H4>Starting a SkirRPC service on an HTTP server</H4>
      <P>
        Full example{' '}
        <a
          href="https://github.com/gepheum/skir-moonbit-example/blob/main/src/start_service.mbt"
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
          href="https://github.com/gepheum/skir-moonbit-example/blob/main/src/call_service.mbt"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>
    </Prose>
  )
}
