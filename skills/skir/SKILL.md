---
name: skir
description: Author, format, evolve, and compile Skir (.skir) data schemas, constants, and SkirRPC methods, configure skir.yml, and integrate generated code across TypeScript, Python, Ruby, Java, Kotlin, Scala, C++, C#, Go, Rust, Dart, Swift, Zig, Gleam, MoonBit, OCaml, and Elixir. Use whenever working with .skir files, skir.yml, skir-snapshot.json, skirout directories, npx skir, or SkirRPC services.
---

# Skir

Skir is a declarative schema language for data types, constants, and RPC methods. You write `.skir` files in `skir-src/` and compile them with `npx skir gen` into deeply immutable, type-safe native code (`skirout/`) for 17 languages.

Full documentation for LLMs: `https://skir.build/llms.txt` (single-file bundle: `https://skir.build/llms-full.txt`).

## Project layout

- `skir.yml`: Project configuration at the project root (`generators`, `dependencies`, `githubTokenEnvVar`).
- `skir-src/`: Directory containing `.skir` schema files (may use subdirectories).
- `skirout/`: Generated output directories (every `outDir` in `skir.yml` **must** end with `/skirout`). **Never edit files inside `skirout/` by hand** — they are overwritten by `npx skir gen`.
- `skir-snapshot.json`: Optional schema snapshot committed to git for automated breaking-change detection via `npx skir snapshot`.
- `skir-external/`: Downloaded GitHub schema dependencies (add to `.gitignore`).

## CLI workflow

Always run `npx skir format` and `npx skir gen` after editing `.skir` files or `skir.yml`:

```bash
npx skir init                # Scaffold skir.yml and skir-src/hello_world.skir
npx skir gen                 # Compile .skir files and generate code (--watch / -w)
npx skir format              # Auto-format all .skir files and resolve `?` stable IDs (--ci to check only)
npx skir snapshot            # Verify no breaking changes against skir-snapshot.json and update it
npx skir snapshot --dry-run  # Check for breaking changes without updating skir-snapshot.json
npx skir snapshot --ci       # CI check: fail if breaking changes exist or snapshot is out of date
npx skir snapshot --view     # Display the last snapshot
```

Pass `--root <dir>` (or `-r <dir>`) to any command if `skir.yml` is not in the current working directory.

## `skir.yml` configuration

```yaml
generators:
  - mod: skir-typescript-gen
    outDir: ./src/skirout
    config: {}
  - mod: skir-python-gen
    outDir: ./backend/src/skirout
    config: {}

# Optional: import .skir files directly from GitHub repositories by tag
dependencies:
  "@gepheum/skir-fantasy-game-example": v1.0.0

# Optional: env var holding a GitHub PAT when dependencies include private repos
githubTokenEnvVar: MY_GITHUB_TOKEN
```

Note: `outDir` can be a single string or an array of strings (all ending with `/skirout`).

### Built-in generators, config options & runtime packages

| Language | `mod` in `skir.yml` | `config` options | Runtime dependency |Language guide |
| --- | --- | --- | --- | --- |
| TypeScript | `skir-typescript-gen` | `importPathExtension?: "" \| ".js"` (default `".js"`), `clientModulePath?: string` | `npm i skir-client` | `https://skir.build/docs/typescript.md` |
| Python | `skir-python-gen` | `packagePrefix?: string` (e.g. `"my_pkg."`) | `pip install skir-client` | `https://skir.build/docs/python.md` |
| Ruby | `skir-ruby-gen` | `modulePrefix?: string` (e.g. `"MyApp::"`) | `gem install skir-client` | `https://skir.build/docs/ruby.md` |
| Java | `skir-java-gen` | `packagePrefix?: string` (e.g. `"com.myproject."`) | `build.skir:skir-client:latest.release` | `https://skir.build/docs/java.md` |
| Kotlin | `skir-kotlin-gen` | `packagePrefix?: string` (e.g. `"com.myproject."`) | `build.skir:skir-client:latest.release` | `https://skir.build/docs/kotlin.md` |
| Scala | `skir-scala-gen` | `packagePrefix?: string` (e.g. `"com.myproject."`) | `build.skir:skir-client:latest.release` | `https://skir.build/docs/scala.md` |
| C++ | `skir-cc-gen` | `writeGoogleTestHeaders?: boolean` | CMake `FetchContent` from `gepheum/skir-cc-gen` (`client` subdir) + `absl` | `https://skir.build/docs/cpp.md` |
| C# | `skir-csharp-gen` | `{}` | `dotnet add package skir_client` | `https://skir.build/docs/csharp.md` |
| Go | `skir-go-gen` | `goModuleName: string` (**required**, must match `go.mod`) | `go get github.com/gepheum/skir-go-client` | `https://skir.build/docs/go.md` |
| Rust | `skir-rust-gen` | `{}` | `cargo add skir-client` (plus `src/skirout.rs` with `pub mod base;`) | `https://skir.build/docs/rust.md` |
| Dart | `skir-dart-gen` | `importUriPrefix?: string` | `dart pub add skir_client` | `https://skir.build/docs/dart.md` |
| Swift | `skir-swift-gen` | `public?: boolean` (default `false`) | SwiftPM `https://github.com/gepheum/skir-swift-client` (`SkirClient`) | `https://skir.build/docs/swift.md` |
| Zig | `skir-zig-gen` | `{}` | `zig fetch` `https://github.com/gepheum/skir-zig-client` (`skir_client`) | `https://skir.build/docs/zig.md` |
| Gleam | `skir-gleam-gen` | `importPathToSkirout?: string` (default `"skirout"`) | `gleam add skir_client` | `https://skir.build/docs/gleam.md` |
| MoonBit | `skir-moonbit-gen` | `{}` | `moon add gepheum/skir-client` | `https://skir.build/docs/moonbit.md` |
| OCaml | `skir-ocaml-gen` | `{}` | `skir_client` (`Skir` module via Dune `(include_subdirs unqualified)`) | `https://skir.build/docs/ocaml.md` |
| Elixir | `skir-elixir-gen` | `namespace?: string` (default `"Skir.Generated"`) | `{:skir_elixir_client, "~> 0.2.1"}` + `npm i -D skir-elixir-gen` | `https://skir.build/docs/elixir.md` |

## `.skir` schema language syntax

```skir
import { Quest } from "@gepheum/skir-fantasy-game-example/fantasy_game.skir";
import { Address } from "common/address.skir";
import * as billing from "billing.skir";

/// A registered user in the system.
/// See [UserRegistry.users] for lookup by [user_id].
struct User(500996846) {
  user_id: int64;
  name: string;
  removed;
  quote: string;

  struct Pet {
    name: string;
    height_in_meters: float32;
    picture: string;
  }
  pets: [Pet];

  subscription_status: SubscriptionStatus;
  email: string?;
}

enum SubscriptionStatus {
  free;
  premium;
  trial: struct {
    start_time: timestamp;
  };
}

struct UserRegistry {
  /// O(1) lookup by user_id in generated code.
  users: [User|user_id];
}

const TARZAN: User = {
  user_id: 123,
  name: "Tarzan",
  quote: "AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA",
  pets: [
    {
      name: "Cheeta",
      height_in_meters: 1.67,
      picture: "🐒",
    },
  ],
  subscription_status: {
    kind: "trial",
    value: {
      start_time: "2025-04-02T11:13:29Z",
    },
  },
  email: null,
};

/// Returns the user with the given ID.
method GetUser(
  struct {
    user_id: int64;
  }
): enum {
  ok: User;
  not_found;
} = ?;
```

### Data types

- **Primitives**:
  - `bool` (default `false`)
  - `int32` (signed 32-bit int, default `0`)
  - `int64` (signed 64-bit int, default `0` — serialized as string in JSON when outside JS safe integer range)
  - `hash64` (unsigned 64-bit int, default `0` — use for hashes/IDs; use `int64` for counts)
  - `float32`, `float64` (IEEE floats, default `0.0`; supports `"NaN"`, `"Infinity"`, `"-Infinity"`)
  - `string` (UTF-8 string, default `""`)
  - `bytes` (byte sequence, default empty; `"hex:..."` in `.skir` constants, Base64 in dense JSON)
  - `timestamp` (instant in time as Unix epoch milliseconds, default epoch `0`; ISO-8601 string in `.skir` constants)
- **Arrays**: `[T]` (default `[]`).
- **Keyed arrays**: `[Item|key_field]` or chained `[Item|a.b.c]`. `Item` must be a struct, and the key must be a primitive or an enum (for enum keys, append `.kind`: `[Item|weekday.kind]`). Generates O(1) hash-indexed lookup methods on the array.
- **Optionals**: `T?` (either `T` or `null`, default `null`).

### Records (`struct` and `enum`)

- **Naming conventions**:
  - Record (`struct`/`enum`) and `method` names: `PascalCase`.
  - Struct fields and enum variants (both constant and wrapper variants): `snake_case`.
  - Constants (`const`): `UPPER_SNAKE_CASE`.
- **Field & variant numbering**:
  - Implicit numbering is recommended: struct fields are 0-based (`0, 1, 2, ...`); enum variants are 1-based (`1, 2, ...`, because `0` is reserved for the implicit `unknown` variant present on every enum).
  - Explicit numbering is also supported (`field_name: type = 0;`), cannot mix implicit and explicit in the same record.
  - When deleting a field or variant, replace it with `removed;` (implicit) or `removed 2..4, 6;` (explicit) so its number is never reused.
- **Nested & inline records**:
  - Records can be nested inside a `struct` or `enum` and referenced with dot notation (`User.Pet`).
  - Inline record shorthand: `field_name: struct { ... }` or `variant_name: struct { ... }` or `field_name: enum { ... }` automatically defines a nested record named `PascalCase(field_name)`.
  - **Restriction**: Inline records **cannot** be wrapped in an array or optional (`[struct { ... }]` and `struct { ... }?` are syntax errors — define a named nested record instead).
- **Stable identifiers**:
  - Top-level persisted records can have a stable ID in parentheses: `struct User(500996846) { ... }` or `struct User(?) { ... }`.
  - Every `method` **must** have a stable numeric ID: `method Foo(Req): Resp = 12345;` or `= ?;`.
  - **Tip**: Always write `?` for new record or method IDs and run `npx skir format` — the formatter replaces `?` with a random unique 32-bit integer automatically.
- **Doc comments**:
  - Use `///` before records, fields, variants, methods, or constants.
  - Reference other schema symbols in square brackets (`/// See [User.name] or [user_id].`). The compiler validates all `[...]` references at build time.

### Constants (`const`)

- JSON-like syntax with unquoted object keys, trailing commas allowed, single or double quotes for strings, `"hex:..."` for `bytes`, and ISO-8601 strings for `timestamp`.
- Enum constant variants are written as strings (`"free"` or `"FREE"`).
- Enum wrapper variants are written as `{ kind: "trial", value: ... }`.
- Full struct literal `{ ... }` requires all fields; partial struct literal `{| ... |}` initializes omitted fields to their default values.

## Serialization formats

Every generated struct and enum exposes a serializer supporting 3 formats:

1. **Dense JSON** (default, **recommended for storage and network**): Structs are encoded as positional JSON arrays indexed by field number (`[42, "John"]`), and enums as variant numbers or `[number, value]` pairs. Compact and **safe across field/variant/type renames**.
2. **Readable JSON** (**debugging only — never persist**): Formatted JSON objects with field names. Breaks if fields are renamed.
3. **Binary**: Compact binary wire format, also rename-safe and compatible across all languages.

Deserializers automatically accept both dense and readable JSON. When round-tripping data through older services, pass the `keep-unrecognized-values` option during deserialization (only for trusted inputs) so unknown future fields are preserved.

## Schema evolution rules

- **Safe changes** (backward & forward compatible):
  - Adding fields to the end of a struct (or with a new explicit number).
  - Adding variants to the end of an enum (or with a new explicit number).
  - Renaming any struct, enum, field, variant, method, or `.skir` file.
  - Removing a field or variant by marking its slot `removed;`.
  - Converting a constant enum variant (`error;`) into a wrapper variant (`error: string;`).
  - Adding, changing, or removing the `|key` on a keyed array `[T|key]`.
  - Widening types: `int32` → `int64`, `float32` ↔ `float64`, `bool` → `int32`/`int64`/`hash64`.
- **Breaking changes** (caught by `npx skir snapshot --dry-run`):
  - Reordering fields/variants with implicit numbering, or changing explicit numbers.
  - Deleting a field/variant without `removed;`, or reusing a removed number.
  - Converting a wrapper enum variant into a constant variant.
  - Changing a method's `= <id>` number.

## Schema design best practices

1. **Wrap in a struct for extensibility**:
   - Wrap array elements (`[Tag]` where `struct Tag { value: string; }` instead of `[string]`) if metadata might be attached later.
   - Always use inline structs (or named structs/enums) for `method` requests and responses (`method GetUser(struct { user_id: int64; }): ...`) rather than bare primitives so you can add fields later without breaking callers.
2. **Model expected outcomes in the method response**: Use an `enum` response (`enum { ok: Product; not_found; invalid_id: string; }`) for domain outcomes instead of relying on HTTP transport errors.
3. **Use `timestamp` for instants** and encode units in numeric duration/quantity field names (`timeout_millis: int64`, `height_in_meters: float32`).
4. **Don't overuse `T?`**: When the zero/empty default (`""`, `0`, `[]`) suffices for "not set", prefer a non-optional field.
5. **Keep nested type names short**: Inside `UserHistory`, name the nested struct `Action` (`UserHistory.Action`), not `HistoricalUserAction`.
