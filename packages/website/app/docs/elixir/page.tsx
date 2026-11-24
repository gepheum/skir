import { CodeBlock, H1, H2, H3, H4, InlineCode, P, Prose } from '@/components/prose'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Elixir - Skir Documentation',
  description: 'Learn how to use Skir-generated Elixir code in your projects',
}

export default function ElixirPage() {
  return (
    <Prose>
      <H1>Elixir</H1>
      <P>
        This guide explains how to use Skir in an Elixir project with the community-maintained{' '}
        <a
          href="https://github.com/mishmish-dev/skir-elixir-gen"
          target="_blank"
          rel="noopener noreferrer"
        >
          <InlineCode>skir-elixir-gen</InlineCode>
        </a>{' '}
        plugin and <InlineCode>skir_elixir_client</InlineCode> runtime.
      </P>

      <H2>Set up</H2>
      <P>
        Requires Elixir 1.18+ and Erlang/OTP 27+. Node.js 20+ is needed for code generation; the
        generated Elixir code runs natively on the BEAM.
      </P>
      <P>Install the generator alongside the Skir compiler:</P>
      <CodeBlock language="bash">{`npm install --save-dev skir skir-elixir-gen`}</CodeBlock>
      <P>
        In your <InlineCode>skir.yml</InlineCode> file, add the following snippet under{' '}
        <InlineCode>generators</InlineCode>:
      </P>
      <CodeBlock language="yaml">{`- mod: skir-elixir-gen
  outDir: ./lib/skirout
  config:
    namespace: SkirExample.Protocol`}</CodeBlock>
      <P>
        The <InlineCode>namespace</InlineCode> option sets the prefix for generated modules. It
        defaults to <InlineCode>Skir.Generated</InlineCode> when omitted.
      </P>
      <P>
        The generated code has a runtime dependency on{' '}
        <a
          href="https://hex.pm/packages/skir_elixir_client"
          target="_blank"
          rel="noopener noreferrer"
        >
          <InlineCode>skir_elixir_client</InlineCode>
        </a>
        . Add it to the dependencies in your <InlineCode>mix.exs</InlineCode>:
      </P>
      <CodeBlock language="elixir">{`{:skir_elixir_client, "~> 0.2.1"}`}</CodeBlock>
      <CodeBlock language="bash">{`mix deps.get
npx skir gen
mix compile`}</CodeBlock>
      <P>
        For a complete project with an HTTP service and Elixir and TypeScript clients, see the{' '}
        <a
          href="https://github.com/mishmish-dev/skir-elixir-example"
          target="_blank"
          rel="noopener noreferrer"
        >
          Elixir example
        </a>
        . The example requires Node.js 22+.
      </P>

      <H2>Elixir generated code guide</H2>
      <P>
        The examples below use the code generated from{' '}
        <a
          href="https://github.com/mishmish-dev/skir-elixir-example/blob/main/skir-src/user.skir"
          target="_blank"
          rel="noopener noreferrer"
        >
          this <InlineCode>.skir</InlineCode> file
        </a>
        . Runnable examples are in{' '}
        <a
          href="https://github.com/mishmish-dev/skir-elixir-example/blob/main/scripts/snippets.exs"
          target="_blank"
          rel="noopener noreferrer"
        >
          <InlineCode>scripts/snippets.exs</InlineCode>
        </a>
        .
      </P>

      <H3>Referring to generated symbols</H3>
      <P>
        Each source file generates a module containing constants and RPC helpers. Records have their
        own nested modules.
      </P>
      <CodeBlock language="elixir">{`# Modules generated from "user.skir".
alias SkirExample.Protocol.UserSkir
alias UserSkir.{SubscriptionStatus, User, UserRegistry}

# The nested User.Pet record has its own module.
alias User.Pet`}</CodeBlock>

      <H3>Struct types</H3>
      <P>
        Skir generates a native Elixir struct for every struct in the <InlineCode>.skir</InlineCode>{' '}
        file. The <InlineCode>new/1</InlineCode> function accepts a keyword list or map; omitted
        fields use their default values.
      </P>
      <CodeBlock language="elixir">{`john =
  User.new(
    user_id: 42,
    name: "John Doe",
    quote: "Coffee is just a socially acceptable form of rage.",
    pets: [Pet.new(name: "Dumbo", height_in_meters: 1.0, picture: "🐘")],
    subscription_status: :free
  )

IO.puts(john.name)
# John Doe

# Every field in default/0 has its zero value.
%User{user_id: 0, name: "", pets: [], subscription_status: :unknown} = User.default()

# Specify only the fields you need.
jane = User.new(%{user_id: 43, name: "Jane Doe"})
"" = jane.quote
[] = jane.pets`}</CodeBlock>
      <P>
        Unknown attributes are rejected by <InlineCode>new/1</InlineCode>. Field values are
        validated during serialization; generated typespecs describe the types for tools such as
        Dialyzer.
      </P>

      <H4>Creating modified copies</H4>
      <CodeBlock language="elixir">{`# Elixir structs are immutable. Use struct update syntax to make a copy.
evil_john = %{john | name: "Evil John", quote: "I solemnly swear I am up to no good."}

"Evil John" = evil_john.name
42 = evil_john.user_id
"John Doe" = john.name`}</CodeBlock>

      <H3>Enum types</H3>
      <P>
        The definition of the <InlineCode>SubscriptionStatus</InlineCode> enum in the{' '}
        <InlineCode>.skir</InlineCode> file is:
      </P>
      <CodeBlock language="skir">{`enum SubscriptionStatus {
  free;
  trial: Trial;
  premium;

  struct Trial {
    start_time: timestamp;
  }
}`}</CodeBlock>
      <P>
        Constant variants are atoms; variants carrying a value are tuples. Every enum has an
        implicit <InlineCode>:unknown</InlineCode> default.
      </P>

      <H4>Constructing enum values</H4>
      <CodeBlock language="elixir">{`# Timestamps are integers representing Unix milliseconds.
start_time = ~U[2025-04-02 11:13:29Z] |> DateTime.to_unix(:millisecond)
trial_status = {:trial, SubscriptionStatus.Trial.new(start_time: start_time)}

statuses = [SubscriptionStatus.default(), :free, :premium, trial_status]
[:unknown, :free, :premium, {:trial, %SubscriptionStatus.Trial{}}] = statuses`}</CodeBlock>

      <H4>Pattern matching on enums</H4>
      <CodeBlock language="elixir">{`get_info_text = fn
  :free -> "Free user"
  :premium -> "Premium user"
  {:trial, trial} -> "On trial since " <> Integer.to_string(trial.start_time)
  :unknown -> "Unknown subscription status"
  {:unknown, _metadata} -> "Unrecognized subscription status"
end

"Free user" = get_info_text.(john.subscription_status)
"On trial since 1743592409000" = get_info_text.(trial_status)`}</CodeBlock>

      <H3>Serialization</H3>
      <P>
        Generated record modules expose JSON and binary codecs. Non-bang functions return{' '}
        <InlineCode>{'{:ok, value}'}</InlineCode> or{' '}
        <InlineCode>{'{:error, %Skir.Error{}}'}</InlineCode>. Functions ending in{' '}
        <InlineCode>!</InlineCode> return the value directly or raise{' '}
        <InlineCode>Skir.Error</InlineCode>.
      </P>
      <CodeBlock language="elixir">{`# Dense JSON uses field numbers rather than names (the default).
# Use this format when you plan to deserialize the value later.
{:ok, john_json} = User.encode_json(john)
{:ok, ^john} = User.decode_json(john_json)

# Readable JSON uses field names. Use it mainly for debugging.
IO.puts(User.encode_json!(john, format: :readable))

# JSON terms and JSON strings are separate APIs.
term = User.to_json!(john)
^john = User.from_json!(term)

# Skir binary is more compact and compatible with other Skir runtimes.
binary = User.encode!(john)
^john = User.decode!(binary)`}</CodeBlock>

      <H3>Primitive serializers</H3>
      <P>
        Use <InlineCode>Skir</InlineCode> functions with a type handle to serialize primitive
        values. Timestamps use Unix milliseconds; bytes use Elixir binaries.
      </P>
      <CodeBlock language="elixir">{`1 = Skir.to_json!(:bool, true)
3 = Skir.to_json!(:int32, 3)
"9223372036854775807" = Skir.to_json!(:int64, 9_223_372_036_854_775_807)
1.5 = Skir.to_json!(:float32, 1.5)
1.5 = Skir.to_json!(:float64, 1.5)
"Foo" = Skir.to_json!(:string, "Foo")
1_743_592_409_000 = Skir.to_json!(:timestamp, start_time)`}</CodeBlock>

      <H3>Composite serializers</H3>
      <P>
        Optional values use <InlineCode>nil</InlineCode>; arrays use lists.
      </P>
      <CodeBlock language="elixir">{`# Optional serializer:
"foo" = Skir.to_json!({:optional, :string}, "foo")
nil = Skir.to_json!({:optional, :string}, nil)

# List serializer:
[1, 0] = Skir.to_json!({:array, :bool}, [true, false])

# Lists of generated records use the record's type handle.
{:ok, users_json} = Skir.encode_json({:array, User.type()}, [john, jane])
{:ok, [^john, ^jane]} = Skir.decode_json({:array, User.type()}, users_json)`}</CodeBlock>

      <H3>Constants</H3>
      <CodeBlock language="elixir">{`# Schema constants are zero-arity functions on the source-file module.
tarzan = UserSkir.tarzan_const()
"Tarzan" = tarzan.name
123 = tarzan.user_id
IO.puts(User.encode_json!(tarzan, format: :readable))`}</CodeBlock>

      <H3>Keyed arrays</H3>
      <P>
        Arrays with a key field generate an index helper returning a map. Duplicate keys raise{' '}
        <InlineCode>ArgumentError</InlineCode>.
      </P>
      <CodeBlock language="skir">{`struct UserRegistry {
  users: [User|user_id];
}`}</CodeBlock>
      <CodeBlock language="elixir">{`registry = UserRegistry.new(users: [john, tarzan])
users_by_id = UserRegistry.index_users(registry)

^john = Map.fetch!(users_by_id, 42)
^tarzan = Map.fetch!(users_by_id, 123)`}</CodeBlock>

      <H3>SkirRPC services</H3>
      <P>
        The example uses Plug with Bandit to serve SkirRPC. Register handlers with the generated
        method helpers, then mount <InlineCode>Skir.RPC.Plug</InlineCode> in your router. Phoenix
        applications can also forward requests to this Plug.
      </P>
      <P>
        <strong>Starting a SkirRPC service on an HTTP server</strong> - full examples in{' '}
        <a
          href="https://github.com/mishmish-dev/skir-elixir-example/blob/main/lib/skir_example/rpc.ex"
          target="_blank"
          rel="noopener noreferrer"
        >
          <InlineCode>rpc.ex</InlineCode>
        </a>{' '}
        and{' '}
        <a
          href="https://github.com/mishmish-dev/skir-elixir-example/blob/main/lib/skir_example/router.ex"
          target="_blank"
          rel="noopener noreferrer"
        >
          <InlineCode>router.ex</InlineCode>
        </a>
        .
      </P>
      <P>
        <strong>Sending RPCs to a SkirRPC service</strong> - full example{' '}
        <a
          href="https://github.com/mishmish-dev/skir-elixir-example/blob/main/scripts/call_service.exs"
          target="_blank"
          rel="noopener noreferrer"
        >
          here
        </a>
        .
      </P>
      <CodeBlock language="elixir">{`alias SkirExample.Protocol.ServiceSkir
alias ServiceSkir.{GetUserRequest, GetUserResponse}

client = Skir.RPC.ServiceClient.new!("http://127.0.0.1:8787/myapi")

{:ok, %GetUserResponse{user: user}} =
  ServiceSkir.get_user(client, GetUserRequest.new(user_id: 123))

# Optional response fields use nil when the user is absent.
case user do
  %User{name: name} -> IO.puts(name)
  nil -> IO.puts("User not found")
end`}</CodeBlock>

      <H3>Reflection</H3>
      <P>
        Reflection allows you to inspect a Skir type at runtime. The generated{' '}
        <InlineCode>type/0</InlineCode> function returns the record&apos;s public type handle.
      </P>
      <CodeBlock language="elixir">{`descriptor = Skir.RPC.TypeDescriptor.to_map(User.type())
%{"type" => %{"kind" => "record", "value" => "user.skir:User"}} = descriptor

# Print the full descriptor as JSON, including referenced records.
IO.puts(Skir.RPC.TypeDescriptor.to_json(User.type()))`}</CodeBlock>
      <P>
        For the full runtime API, see{' '}
        <a href="https://hexdocs.pm/skir_elixir_client" target="_blank" rel="noopener noreferrer">
          HexDocs
        </a>
        .
      </P>
    </Prose>
  )
}
