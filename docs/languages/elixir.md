# Elixir

This guide explains how to use Skir in an Elixir project with the community-maintained [`skir-elixir-gen`](https://github.com/mishmish-dev/skir-elixir-gen) plugin and `skir_elixir_client` runtime.

## Set up

Requires Elixir 1.18+ and Erlang/OTP 27+. Node.js 20+ is needed for code generation; the generated Elixir code runs natively on the BEAM.

Install the generator alongside the Skir compiler:

```bash
npm install --save-dev skir skir-elixir-gen
```

In your `skir.yml` file, add the following snippet under `generators`:

```yaml
- mod: skir-elixir-gen
  outDir: ./lib/skirout
  config:
    namespace: SkirExample.Protocol
```

The `namespace` option sets the prefix for generated modules. It defaults to `Skir.Generated` when omitted.

The generated code has a runtime dependency on [`skir_elixir_client`](https://hex.pm/packages/skir_elixir_client) . Add it to the dependencies in your `mix.exs`:

```elixir
{:skir_elixir_client, "~> 0.2.1"}
```

```bash
mix deps.get
npx skir gen
mix compile
```

For a complete project with an HTTP service and Elixir and TypeScript clients, see the [Elixir example](https://github.com/mishmish-dev/skir-elixir-example) . The example requires Node.js 22+.

## Elixir generated code guide

The examples below use the code generated from [this `.skir` file](https://github.com/mishmish-dev/skir-elixir-example/blob/main/skir-src/user.skir) . Runnable examples are in [`scripts/snippets.exs`](https://github.com/mishmish-dev/skir-elixir-example/blob/main/scripts/snippets.exs) .

### Referring to generated symbols

Each source file generates a module containing constants and RPC helpers. Records have their own nested modules.

```elixir
# Modules generated from "user.skir".
alias SkirExample.Protocol.UserSkir
alias UserSkir.{SubscriptionStatus, User, UserRegistry}

# The nested User.Pet record has its own module.
alias User.Pet
```

### Struct types

Skir generates a native Elixir struct for every struct in the `.skir` file. The `new/1` function accepts a keyword list or map; omitted fields use their default values.

```elixir
john =
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
[] = jane.pets
```

Unknown attributes are rejected by `new/1`. Field values are validated during serialization; generated typespecs describe the types for tools such as Dialyzer.

#### Creating modified copies

```elixir
# Elixir structs are immutable. Use struct update syntax to make a copy.
evil_john = %{john | name: "Evil John", quote: "I solemnly swear I am up to no good."}

"Evil John" = evil_john.name
42 = evil_john.user_id
"John Doe" = john.name
```

### Enum types

The definition of the `SubscriptionStatus` enum in the `.skir` file is:

```skir
enum SubscriptionStatus {
  free;
  trial: Trial;
  premium;

  struct Trial {
    start_time: timestamp;
  }
}
```

Constant variants are atoms; variants carrying a value are tuples. Every enum has an implicit `:unknown` default.

#### Constructing enum values

```elixir
# Timestamps are integers representing Unix milliseconds.
start_time = ~U[2025-04-02 11:13:29Z] |> DateTime.to_unix(:millisecond)
trial_status = {:trial, SubscriptionStatus.Trial.new(start_time: start_time)}

statuses = [SubscriptionStatus.default(), :free, :premium, trial_status]
[:unknown, :free, :premium, {:trial, %SubscriptionStatus.Trial{}}] = statuses
```

#### Pattern matching on enums

```elixir
get_info_text = fn
  :free -> "Free user"
  :premium -> "Premium user"
  {:trial, trial} -> "On trial since " <> Integer.to_string(trial.start_time)
  :unknown -> "Unknown subscription status"
  {:unknown, _metadata} -> "Unrecognized subscription status"
end

"Free user" = get_info_text.(john.subscription_status)
"On trial since 1743592409000" = get_info_text.(trial_status)
```

### Serialization

Generated record modules expose JSON and binary codecs. Non-bang functions return `{:ok, value}` or `{:error, %Skir.Error{}}`. Functions ending in `!` return the value directly or raise `Skir.Error`.

```elixir
# Dense JSON uses field numbers rather than names (the default).
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
^john = User.decode!(binary)
```

### Primitive serializers

Use `Skir` functions with a type handle to serialize primitive values. Timestamps use Unix milliseconds; bytes use Elixir binaries.

```elixir
1 = Skir.to_json!(:bool, true)
3 = Skir.to_json!(:int32, 3)
"9223372036854775807" = Skir.to_json!(:int64, 9_223_372_036_854_775_807)
1.5 = Skir.to_json!(:float32, 1.5)
1.5 = Skir.to_json!(:float64, 1.5)
"Foo" = Skir.to_json!(:string, "Foo")
1_743_592_409_000 = Skir.to_json!(:timestamp, start_time)
```

### Composite serializers

Optional values use `nil`; arrays use lists.

```elixir
# Optional serializer:
"foo" = Skir.to_json!({:optional, :string}, "foo")
nil = Skir.to_json!({:optional, :string}, nil)

# List serializer:
[1, 0] = Skir.to_json!({:array, :bool}, [true, false])

# Lists of generated records use the record's type handle.
{:ok, users_json} = Skir.encode_json({:array, User.type()}, [john, jane])
{:ok, [^john, ^jane]} = Skir.decode_json({:array, User.type()}, users_json)
```

### Constants

```elixir
# Schema constants are zero-arity functions on the source-file module.
tarzan = UserSkir.tarzan_const()
"Tarzan" = tarzan.name
123 = tarzan.user_id
IO.puts(User.encode_json!(tarzan, format: :readable))
```

### Keyed arrays

Arrays with a key field generate an index helper returning a map. Duplicate keys raise `ArgumentError`.

```skir
struct UserRegistry {
  users: [User|user_id];
}
```

```elixir
registry = UserRegistry.new(users: [john, tarzan])
users_by_id = UserRegistry.index_users(registry)

^john = Map.fetch!(users_by_id, 42)
^tarzan = Map.fetch!(users_by_id, 123)
```

### SkirRPC services

The example uses Plug with Bandit to serve SkirRPC. Register handlers with the generated method helpers, then mount `Skir.RPC.Plug` in your router. Phoenix applications can also forward requests to this Plug.

**Starting a SkirRPC service on an HTTP server** - full examples in [`rpc.ex`](https://github.com/mishmish-dev/skir-elixir-example/blob/main/lib/skir_example/rpc.ex) and [`router.ex`](https://github.com/mishmish-dev/skir-elixir-example/blob/main/lib/skir_example/router.ex) .

**Sending RPCs to a SkirRPC service** - full example [here](https://github.com/mishmish-dev/skir-elixir-example/blob/main/scripts/call_service.exs) .

```elixir
alias SkirExample.Protocol.ServiceSkir
alias ServiceSkir.{GetUserRequest, GetUserResponse}

client = Skir.RPC.ServiceClient.new!("http://127.0.0.1:8787/myapi")

{:ok, %GetUserResponse{user: user}} =
  ServiceSkir.get_user(client, GetUserRequest.new(user_id: 123))

# Optional response fields use nil when the user is absent.
case user do
  %User{name: name} -> IO.puts(name)
  nil -> IO.puts("User not found")
end
```

### Reflection

Reflection allows you to inspect a Skir type at runtime. The generated `type/0` function returns the record's public type handle.

```elixir
descriptor = Skir.RPC.TypeDescriptor.to_map(User.type())
%{"type" => %{"kind" => "record", "value" => "user.skir:User"}} = descriptor

# Print the full descriptor as JSON, including referenced records.
IO.puts(Skir.RPC.TypeDescriptor.to_json(User.type()))
```

For the full runtime API, see [HexDocs](https://hexdocs.pm/skir_elixir_client) .
