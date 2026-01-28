# Coming from Protocol Buffers

If you have used [Protocol Buffers](https://protobuf.dev/) (protobuf) before, you will find Skir very familiar. Skir was heavily inspired by protobuf and shares many of its core design principles: efficient binary serialization, schema evolution, and language-agnostic types.

However, Skir was built to address common pain points in the protobuf ecosystem and to provide a superior developer experience. This guide highlights the key differences.

## Language differences

### Constants

Skir lets you define constants directly in your schema files. You can define complex values (structs, lists, maps, primitives) in your `.skir` file and they will be compiled into native code constants in your target language.

```d
// config.skir

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

### Unified enums and oneof

In Protocol Buffers, an `enum` represents one of multiple stateless options, and a `oneof` represents one of multiple stateful options. This often leads to awkward patterns when you want a mix of stateless and stateful options, for example:

```protobuf
// poker.proto

message PokerAction {
  enum Enum {
    UNKNOWN = 0;
    CHECK = 1;
    BET = 2;
    CALL = 3;
    FALL = 4;
    RAISE = 5;
  }
  Enum action = 1;
  // Only if action is BET or RAISE
  int32 amount = 2;
}
```

Skir unifies these two concepts into a specific "Rust-like" enum. Variants can be stateless (like a standard enum) or stateful (holding data), and you can mix them freely.

```d
enum PokerAction {
  CHECK;       // Stateless variant
  bet: int32;  // Stateful variant (holds the amount)
  FOLD;
  CALL;
  raise: int32;
}
```

### Implicit `UNKNOWN` variant

The [Protobuf Style Guide](https://protobuf.dev/style-guide/) requires you to manually add an `UNSPECIFIED` value as the first entry of every enum to handle default values safely:

> Enums should include a default `FOO_UNSPECIFIED` value as the first value in the declaration. When new values are added to an enum, old clients will see the field as unset and the getter will return the default value or the first-declared value if no default exists . For consistent behavior with proto enums, the first declared enum value should be a default FOO_UNSPECIFIED value and should use tag 0. 

Skir does this automatically. Every enum in Skir has an implicit `UNKNOWN` variant (with index 0). This serves as the default value and captures unrecognized variants deserialized from newer schema versions.

### Keyed arrays vs maps

Protocol Buffer 3 introduced the `map<K, V>` type with the goal of preventing developers from having to manually iterate through lists to find items. Such manual iteration is cumbersome and inefficient if multiple lookups have to be performed.

Unfortunately, `map` comes with a trade-off: in the majority of cases, the key used for indexing is already stored inside the value type.

**Protobuf:**
```protobuf
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

Skir introduces *Keyed Arrays* to solve this problem. You define an array and tell the compiler which field of the value acts as the key.

```d
struct User {
  id: string;
  name: string;
}

struct UserRegistry {
  // Serialized as a list, but indexed by 'id' in generated code
  users: [User|id];
}
```

On the wire, `users` is serialized as a plain list of `User` objects. In the generated code, Skir automatically creates methods to perform O(1) lookups by `id`. You get the performance of a map with the storage efficiency of a list.

## Differences in generated code

Although the differences between the protobuf-generated code and the Skir-generated code largely depend on the targeted language, there are some general patterns across languages.

### Adding fields to a type

This is a fundamental difference in design philosophy.

With Protocol Buffers, adding a field to a message is guaranteed **not** to break existing code that constructs instances of that message. If the code isn't updated, the new field simply takes its default value (0, empty string, etc.).

Skir takes the opposite approach: it aims to raise a compile-time error if you add a field to a struct but forget to update the code that constructs it. When you add a field, you usually *want* to update every instantiation site to populate that field correctly. Skir ensures you don't miss any spot by enforcing strict constructors.

**Protobuf:**
```python
# my_script_with_protobuf.py

# Adding 'email' to User message doesn't break this code.
user = User()
user.id = 123
user.name = "Alice"
```

**Skir:**
```python
# my_script_with_skir.py

# Static type checkers will raise an error if 'email' is added to User in the
# schema file and this code is not updated.
user = User(
    id=123,
    name="Alice",
)
```

> **Note:** When deserializing old data that is missing the new field, both Protobuf and Skir behave similarly: the new field is assigned its default value.

### Immutability

In most languages, the Skir compiler generates two versions of each `struct` type: an immutable one and a mutable one.

Immutable types generally help write safer, more predictable, and thread-safe code. However, there are some cases where immutability is overkill and mutable types are simply easier to use.

Skir lets you pick on a case-by-case basis which version you want to use. It creates methods allowing you to easily convert between immutable and mutable, and these functions have smart logic to avoid unnecessary copies.

In contrast, Protocol Buffers typically does not generate immutable types in languages like TypeScript and Python.

## Package management

Protocol Buffers does not come with a built-in package manager. To share types across multiple Git repositories, developers traditionally have to rely on `git submodule`, manual file copying, or external commercial services like `buf`.

Skir includes a built-in, free package manager that treats **GitHub repositories as packages**. This allows you to easily share common data structures (like standard currency types or user definitions) across your backend microservices and your frontend applications.

1.  Define dependencies in `skir.yml`, pointing to any public or private GitHub repository and a tag.
2.  Import the types you need: `import User from "@my-org/common-types/user.skir";`.
3.  Run `npx skir gen`.

Skir handles downloading the repositories from GitHub, caching them, and resolving imports automatically. You get a full-featured schema registry experience using just your existing source control.

## Serialization flexibility

Protobuf has two main formats: Binary and JSON (Proto3 JSON Mapping).

The Protobuf JSON format is *readable* (uses field names), but because field names can change, it is not safe for long-term storage or schema evolution.

Skir lets you choose between three formats:
1.  **Binary**: Equivalent to Protobuf binary. Compact and fast.
2.  **Readable JSON**: Like Protobuf JSON. Good for debugging, bad for specific schema evolution cases (renames).
3.  **Dense JSON**: A unique Skir format which is often the best default choice. It serializes structs as JSON arrays (`[val1, val2, ...]`) instead of objects.
    *   **Compact**: Smaller than readable JSON, and often only ~20% larger than the binary format.
    *   **Evolution-safe**: Uses field numbers, not names. You can rename fields without breaking compatibility.
    *   **Storage-ready**: Perfect for storing data in text-based columns (like PostgreSQL JSONB) while maintaining the ability to rename fields in your schema.

## Services & RPC

Protobuf is tightly coupled with gRPC. While you *can* use Protobuf with other transports, gRPC is the default and often the only easy path.

Skir is transport-agnostic. It gives you a generic `Service` interface that handles routing and serialization/deserialization. You can hook this into *any* HTTP server or transport layer. This allows you to support high-performance binary RPCs for microservices (similar to gRPC) while simultaneously serving standard JSON over HTTP for browser clients, all without needing a proxy.

Skir services are designed to be embedded into your existing application (Express, Flask, Spring Boot, etc.) rather than forcing you to run a separate server.
