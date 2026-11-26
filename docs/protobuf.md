# Skir vs Protobuf

If you have used [Protocol Buffers](https://protobuf.dev/) (protobuf) before, you will find Skir very familiar. Skir was heavily inspired by protobuf and shares many of its core design principles: efficient binary serialization, schema evolution, and language-agnostic types.

However, Skir was built to address common pain points in the protobuf ecosystem and to provide a superior developer experience. This guide highlights the key differences.

## Polymorphism

In Protocol Buffers, an `enum` represents one of multiple stateless options, and a `oneof` represents one of multiple stateful options. This often leads to awkward patterns when you want a mix of stateless and stateful options, for example:

```protobuf
// poker.proto

message PokerAction {
  enum Enum {
    UNKNOWN = 0;
    CHECK = 1;
    BET = 2;
    CALL = 3;
    FOLD = 4;
    RAISE = 5;
  }
  Enum action = 1;
  // Only if action is BET or RAISE
  int32 amount = 2;
}
```

Skir unifies these two concepts into a specific "Rust-like" enum. Variants can be stateless (like a standard enum) or stateful (holding data), and you can mix them freely.

```skir
enum PokerAction {
  check;           // Stateless variant
  bet: int32;      // Stateful variant (holds the amount)
  fold;
  call;
  raise: int32;
}
```

## Must all fields be specified at construction time?

This reflects a fundamental difference in code generation philosophy between Skir and Protobuf.

With Protocol Buffers, adding a field to a message is guaranteed **not** to break existing code that constructs instances of that message. If the code isn't updated, the new field simply takes its default value (0, empty string, etc.).

Skir takes the opposite approach: it aims to raise a compile-time error if you add a field to a struct but forget to update the code that constructs it. When you add a field, you usually _want_ to update every instantiation site to populate that field correctly. Skir ensures you don't miss any spot by enforcing strict constructors.

```python [Protobuf]
# my_script_with_protobuf.py

# Adding 'email' to User message doesn't break this code.
user = User()
user.id = 123
user.name = "Alice"
```

```python [Skir]
# my_script_with_skir.py

# Static type checkers will raise an error if 'email' is added to User in the
# schema file and this code is not updated.
user = User(
    id=123,
    name="Alice",
)
```

If you need to opt out explicitly, Skir also generates a `partial` constructor. This is useful for test fixtures, where updating every constructor call can become cumbersome when fields are added to a `struct`.

```python [Skir (explicit opt-out)]
user = User.partial(
    id=123,
    # no name
)
```

When deserializing old data that is missing the new field, both Protobuf and Skir behave similarly: the new field is assigned its default value.

## Schema evolution: guidelines vs guarantees

Both Protocol Buffers and Skir are designed to support schema evolution, but they take fundamentally different approaches to ensuring compatibility.

Protocol Buffers provides [guidelines and best practices](https://protobuf.dev/programming-guides/proto3/#updating) for evolving schemas safely. These guidelines tell you which changes are safe (e.g., adding fields, renaming) and which are dangerous (e.g., changing field numbers, incompatible type changes). However, **nothing in the toolchain enforces these rules**. It is entirely up to developers to remember the guidelines, understand the implications, and avoid making breaking changes.

Skir takes a different approach: it provides **automated enforcement** through its built-in snapshot tool. When you run `npx skir snapshot`, Skir analyzes your current schema against a stored snapshot of the previous version and automatically detects breaking changes. If you accidentally change a field number or make an incompatible type change, Skir will catch it and refuse to proceed.

This shift from _guidelines you must remember to follow_ to _automated checks that prevent mistakes_ provides a much stronger guarantee of compatibility. You can confidently evolve your schema knowing that the tooling will catch any dangerous changes before they reach production. Additionally, when integrated into your CI pipeline or Git pre-commit hooks, the snapshot check ensures that every schema change is validated automatically.

### A note on `buf breaking`

Buf has addressed this gap in the Protobuf ecosystem with its [`buf breaking`](https://buf.build/docs/breaking/) command, which detects backward-incompatible schema changes. However, it identifies types purely by their fully-qualified name. This means renaming a type — even a simple refactor — is treated as a breaking change: the old type is seen as deleted and a new one created, losing all compatibility history.

Skir avoids this by letting you assign a [stable numeric identifier](https://skir.build/docs/schema-evolution#tracked-types-and-stable-identifiers) to your top-level types. This identifier is a meaningless number — purely internal to the compiler — so you can rename a type freely without breaking compatibility. It also lets Skir automatically track all the nested types a top-level type references, without requiring you to annotate each one manually.

## External dependencies

Protocol Buffers does not come with a built-in package manager. To share types across multiple Git repositories, developers traditionally have to rely on `git submodule`, manual file copying, or external commercial services like `buf`.

Skir supports GitHub imports, like Go and Swift. This allows you to easily share common data structures (like standard currency types or user definitions) across your backend microservices and your frontend applications.

1. Define dependencies in `skir.yml`, pointing to any public or private GitHub repository and a tag.
2. Import the types you need: `{'import { User } from "@my-org/common-types/user.skir";'}`
3. Run `npx skir gen`.

Skir handles downloading the repositories from GitHub, caching them, and resolving imports automatically. You get a full-featured schema registry experience using just your existing source control.

## Serialization

Protobuf has two serialization formats: Binary and JSON (Proto3 JSON Mapping).

The Protobuf JSON format is readable (uses field names), but is not safe for schema evolution (renaming fields breaks compatibility).

Skir offers three serialization formats:

- **JSON (Dense)**: Structs are serialized as arrays (`[val1, val2]` ) rather than objects. It is the default choice offering the best balance between:
  - Space efficiency: although it is not as space efficient as binary, it comes close.
  - Evolution safety: you can rename fields without breaking compatibility.
  - Interoperability and debuggability: being valid JSON, it is easy to inspect and works out of the box with databases (e.g., PostgreSQL JSONB columns) and external tools, unlike binary formats.
- **JSON (Readable)**: Similar to Protobuf's JSON mapping. Useful for debugging but unsafe for persistence as it relies on field names.
- **Binary**: Equivalent to Protobuf binary. A bit more compact and performant than dense JSON.

Skir can also serialize schemas themselves, so you can store schema metadata alongside your data. This enables generic tooling that can inspect serialized payloads. For example, the [Skir converter web app](https://skir.build/converter.html) can load a schema from a type descriptor JSON or from a GitHub URL, then convert a pasted value between dense JSON, readable JSON, and binary formats.

<HoverVideo src="/skir-converter-github.mp4" />

## Constants

Skir lets you define constants directly in your schema files. You can define complex values (structs, lists, maps, primitives) in your `.skir` file and they will be compiled into native code constants in your target language.

```skir [config.skir]
struct Config {
  timeout_ms: int32;
  retries: int32;
  supported_locales: [string];
}

const DEFAULT_CONFIG: Config = {
  timeout_ms = 5000,
  retries = 3,
  supported_locales = ["en-US", "ja-JP", "fr-FR"],
};
```

The `DEFAULT_CONFIG` constant is compiled into native code, ensuring your frontend and backend share the exact same configuration values.

## Keyed arrays vs maps

Protocol Buffer 3 introduced the `map<K, V>` type with the goal of preventing developers from having to manually iterate through lists to find items. Such manual iteration is cumbersome and inefficient if multiple lookups have to be performed.

Unfortunately, `map` comes with a trade-off: in the majority of cases, the key used for indexing is already stored inside the value type.

```protobuf [Protobuf]
message User {
  string id = 1;
  string name = 2;
}

message UserRegistry {
  // Redundant: 'id' is stored in the map key AND the User
  map<string, User> users = 1;
}
```

This forces you to store the ID twice and creates an implicit contract: the code constructing the map must ensure the key matches the ID inside the value.

Skir introduces _Keyed Arrays_ to solve this problem. You define an array and tell the compiler which field of the value acts as the key.

```skir [Skir]
struct User {
  id: string;
  name: string;
}

struct UserRegistry {
  // Serialized as a list, but indexed by 'id' in generated code
  users: [User|id];
}
```

On the wire, `users` is serialized as a plain list of `User` objects. In the generated code, Skir automatically creates methods to perform O(1) lookups by `id`.

## SkirRPC vs gRPC

Protobuf is typically paired with gRPC. While efficient, gRPC requires specific tooling for debugging (like `grpcui`) and often needs a proxy (gRPC-Web) to be called from a browser.

SkirRPC services run over standard HTTP and are designed to be embedded into your existing application (Express, Flask, Spring Boot, etc.). This makes them naturally compatible with web clients and easy to inspect with standard tools like cURL.

Additionally, every SkirRPC service comes with **Skir Studio** out of the box. This built-in interactive debugging interface allows you to explore your API and test methods directly in your browser, without needing to install or configure any external tools.

<HoverVideo src="/rpc-studio.mp4" />

## Other differences

### Implicit unknown variant

The [Protobuf Style Guide](https://protobuf.dev/programming-guides/style/) requires you to manually add an `UNSPECIFIED` value as the first entry of every enum to handle default values safely:

>

The first listed value should be a zero value enum and have the suffix of either `_UNSPECIFIED` or `_UNKNOWN`. This value may be used as an unknown/default value and should be distinct from any of the semantic values you expect to be explicitly set. For more information on the unspecified enum value, see the Proto Best Practices page.

Skir does this automatically. Every enum in Skir has an implicit `unknown` variant (with index 0). This serves as the default value and captures unrecognized variants deserialized from newer schema versions.

### Field numbering

In Skir, fields in a `struct` are numbered starting from 0, and they must use sequential integers (no gaps allowed). With Protobuf, field numbers must be greater than 0, and can be sparse (you can skip numbers).

### Imports

Protobuf imports work like C includes: importing a `.proto` file brings all of its symbols into scope without any explicit listing. If you encounter a type like `Foo` that is not defined in the current file, you cannot tell which imported file it comes from without opening each one. Skir uses named imports, similar to TypeScript and Python: you explicitly list which names you are importing and from which module, making every dependency immediately traceable.

### API definitions

In Protocol Buffers, service methods are grouped into `service` blocks. In Skir, methods are defined globally in the schema, and grouping is decided in the application code.

In Protocol Buffers, service methods are identified by their name. In Skir, methods are identified by a numeric ID. This makes it safe to rename methods without breaking compatibility.

### Immutability

Skir leans toward immutable generated data types, even in languages where that pattern is less common. In Python and TypeScript, for example, it generates two versions of each type: a deeply immutable one and a mutable one, with conversion methods between them. Protobuf generates only mutable data classes in these languages.

## Final note on Buf

Both Skir and [Buf](https://buf.build/) were created to solve the same fundamental gaps in the Protobuf ecosystem: providing a seamless workflow with integrated dependency management, linting, formatting, and breaking-change detection.

The difference lies in philosophy. Buf builds the best possible ecosystem around the Protobuf language as it exists today. Skir, however, operates on the belief that Protobuf's core design flaws are significant enough to justify a new language. This mirrors recurring industry "evolution vs. revolution" debates, much like TypeScript vs. Dart or Carbon vs. Rust. While introducing a new language adds adoption cost, one can argue that without moving beyond legacy constraints, meaningful progress in developer experience remains limited.
