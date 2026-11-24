[![npm](https://img.shields.io/npm/v/skir-elixir-gen)](https://www.npmjs.com/package/skir-elixir-gen)
[![Hex](https://img.shields.io/hexpm/v/skir_elixir_client)](https://hex.pm/packages/skir_elixir_client)
[![HexDocs](https://img.shields.io/badge/runtime_docs-HexDocs-blue)](https://hexdocs.pm/skir_elixir_client)
[![build](https://github.com/mishmish-dev/skir-elixir-gen/actions/workflows/ci.yml/badge.svg)](https://github.com/mishmish-dev/skir-elixir-gen/actions/workflows/ci.yml)

# skir-elixir-gen — native Elixir code generation for Skir

An unofficial Skir compiler plugin that emits native Elixir structs, enums,
codecs, constants, reflection and RPC helpers. Generated code uses the separate
[skir_elixir_client](https://hex.pm/packages/skir_elixir_client) Hex package.

## Set up

Requires Node 20+ for generation, and Elixir 1.18+ with Erlang/OTP 27+ for the
runtime. The runtime uses built-in `JSON` and has no production dependencies.

Add the runtime dependency to your application's `mix.exs`:

```elixir
{:skir_elixir_client, "~> 0.2.1"}
```

The Hex package is `skir_elixir_client`; its Mix application is `:skir_elixir_client`, and
its public modules use `Skir.*`. Run `mix deps.get`.

Install the generator alongside the Skir compiler:

```sh
npm install --save-dev skir skir-elixir-gen
```

Add this entry under `generators` in your `skir.yml`:

```yaml
generators:
  - mod: skir-elixir-gen
    outDir: ./lib/skirout
    config:
      namespace: MyApp.Protocol
```

Run `npx skir gen` before `mix compile`. Node is required for generation,
not for running the generated Elixir code.

`namespace` is the only generator option. It defaults to `Skir.Generated` and
must be an Elixir module namespace.

## Elixir generated-code guide

The examples below use [the example schema](example/skir-src/user.skir) with
`namespace: Example.Protocol`. Follow the same pattern with your own namespace.

### Referring to generated symbols

Each source file has a module for its constants and RPC helpers, with nested
modules for its records:

```elixir
alias Example.Protocol.UserSkir
alias Example.Protocol.UserSkir.{User, Event}

# A nested User.Pet record has its own module.
alias Example.Protocol.UserSkir.User.Pet
```

GitHub schema dependencies use Skir's normal [`dependencies` configuration](https://skir.build/docs/dependencies),
including transitive imports. An import from `@acme/shared-models/accounts/user.skir`
generates `MyApp.Protocol.External.Acme.SharedModels.Accounts.UserSkir.User` in
`external/acme/shared_models/accounts/user_skir.ex`. Numeric or punctuation-only
owner/repository names gain an `N` prefix in Elixir module names. The original
import path remains in reflection IDs. Names that normalize to the same module
or output path are rejected, including collisions with local `external/...` schemas.

### Struct types

Skir structs become native Elixir structs. `new/1` accepts a map or keyword list;
omitted fields use schema defaults.

```elixir
user = User.new(id: 42, name: "Alice")
%User{id: 42, name: "Alice"} = user

%User{id: 0, name: ""} = User.default()
from_map = User.new(%{id: 43, name: "Bob"})
```

`new/1` rejects unknown attributes. Field values are validated when serializing;
typespecs do not enforce them at construction time.

#### Creating modified copies

Structs are immutable. Use Elixir's update syntax to copy a value with changes:

```elixir
updated = %{user | name: "Bob"}
"Alice" = user.name
"Bob" = updated.name
```

#### Optional and array fields

Optional fields use `nil` or the underlying value. Arrays use lists, including
lists of nested generated records:

```elixir
nil = User.default().nickname
family = User.new(nickname: "Al", pets: [Pet.new(name: "Mo")])
"Al" = family.nickname
[%Pet{name: "Mo"}] = family.pets
```

Keyed arrays also generate `index_<field>/1` helpers. These return a map and raise
`ArgumentError` on duplicate keys. See [native API examples](example/test/generated_api_test.exs)
for nested key paths and enum-kind indexes.

### Enum types

Constant variants are atoms; variants carrying a value are tuples. Every enum
also has an implicit `:unknown` default:

```elixir
connected = :connected
message = {:message, "Hello"}
event = {:user_created, user}
:unknown = Event.default()
```

Use ordinary Elixir pattern matching:

```elixir
case event do
  :connected -> "Connected"
  {:user_created, %User{name: name}} -> name
  {:message, text} -> text
  :unknown -> "Unknown event"
  {:unknown, _metadata} -> "Preserved future event"
end
```

The tuple form of an unknown variant is used when explicitly preserving future
values. See the [runtime codec guide](https://github.com/mishmish-dev/skir-elixir-client/blob/main/docs/CODECS.md)
for schema evolution and unknown-field policies.

### Serialization

```elixir
# JSON terms and JSON strings are separate APIs.
[42, 0, "Alice"] = User.to_json!(user)
{:ok, json} = User.encode_json(user)
{:ok, ^user} = User.decode_json(json)

# Framed Skir binary, not Erlang external-term format.
{:ok, binary} = User.encode(user)
{:ok, ^user} = User.decode(binary)

# Pure Elixir sum types: atoms for constants, tuples for payloads.
{:ok, event_binary} = Event.encode(event)
{:ok, {:user_created, %User{id: 42}}} = Event.decode(event_binary)

# Debug representation; do not use readable JSON as a rename-safe contract.
%{"id" => 42, "name" => "Alice"} = User.to_json!(user, format: :readable)
```

The zero between `id` and `name` is the example schema's permanently removed
field 1. It is not an inferred field position.


Every generated record module has `default/0`, `type/0`,
and these function pairs, each accepting keyword options:

```elixir
User.to_json(value)       # {:ok, JSON-compatible Elixir term}
User.from_json(term)      # {:ok, %User{}}
User.encode_json(value)   # {:ok, UTF-8 JSON binary}
User.decode_json(json)    # {:ok, %User{}}
User.encode(value)        # {:ok, framed Skir binary}
User.decode(binary)      # {:ok, %User{}}; JSON bytes are also accepted
# The same names ending in ! return the value or raise Skir.Error.
```

Non-bang serialization functions return `{:error, %Skir.Error{reason: atom,
path: [...], message: string}}` on validated input failures. Unexpected programming
errors are not swallowed. Struct modules additionally expose `new/1`.

See the [runtime codec guide](https://github.com/mishmish-dev/skir-elixir-client/blob/main/docs/CODECS.md)
for primitive mappings, recursive defaults, encoding rules and resource limits,
and the [runtime API reference](https://hexdocs.pm/skir_elixir_client/Skir.html)
for serializing primitive and composite type handles directly.

### Constants

Constants are zero-arity functions on the source-file module:

```elixir
alias Example.Protocol.UserSkir
alice = UserSkir.alice_const()
```

### SkirRPC services

The same source module also exposes native SkirRPC helpers. For the example
`GetUser` method:

```elixir
alias Example.Protocol.UserSkir
alias Example.Protocol.UserSkir.User
alias Skir.RPC.{Service, ServiceClient}

service =
  Service.new()
  |> UserSkir.add_get_user(fn id, _metadata ->
    {:ok, %User{id: id, name: "Alice"}}
  end)

client = ServiceClient.new!("https://api.example.com/rpc")
{:ok, %User{}} = UserSkir.get_user(client, 42)
%User{} = UserSkir.get_user!(client, 42)
```

Phoenix/Plug applications can mount `Skir.RPC.Plug` with `forward "/rpc",
Skir.RPC.Plug, service: &MyApp.RPC.service/0`. Studio (`?studio`), method
reflection (`?list`), controlled/unknown errors, request metadata, the compact
SkirRPC HTTP wire format, and a pluggable client transport are implemented. See
[the client RPC guide](https://hexdocs.pm/skir_elixir_client/skirrpc.html) for the complete API and
[the client parity audit](https://hexdocs.pm/skir_elixir_client/skirrpc_parity.html) for the official-runtime parity audit.

### Reflection

Inspect any generated type with `Skir.RPC.TypeDescriptor`:

```elixir
descriptor = Skir.RPC.TypeDescriptor.to_map(User.type())
json = Skir.RPC.TypeDescriptor.to_json(User.type())
```

Descriptors include nested types, field numbers, enum variants, documentation,
and removed slots. `User.type/0` is the public type handle; `schema/0` is internal
codec metadata. See the [runtime API reference](https://hexdocs.pm/skir_elixir_client).

## Tests and benchmarks

```sh
npm ci
mix local.hex
mix local.rebar
npm run test:all
```

`test:all` runs syntax, lint, formatting, coverage, compiler/runtime integration,
malformed-input and npm package checks. Use `npm test` for just the Node generator tests.

Run codec benchmarks separately:

```sh
npm run test:benchmark
```

This builds an OTP release and measures binary and JSON encoding/decoding.
Five-sample median throughput and environment details are saved to
`.artifacts/release-benchmark.json`.

## See also

- [Runtime API reference](https://hexdocs.pm/skir_elixir_client)
