# Skir Code Generator & Client Library Principles

This document is a comprehensive reference for building new Skir code generators
and client libraries. It is derived by studying the six existing language
implementations in depth (TypeScript, Python, C++, Java, Kotlin, Dart) — both
the generated code and the client (runtime) libraries on which that code depends.

---

## 1. What Is Skir?

Skir is a modern, language-agnostic schema definition language (IDL) similar in
spirit to Protocol Buffers. You write schemas in `.skir` files; a code generator
("plugin") produces idiomatic, type-safe code for your target language. A small
runtime library ("client library") ships alongside the generated code and handles
serialization, deserialization, and RPC machinery.

Key design goals:
- **Dense JSON by default, binary available.** Field numbers (not names) drive
  the serialization format, so fields can be renamed without breaking old data.
- **Immutability by default.** Frozen (deeply immutable) structs are the primary
  type; a mutable variant exists for construction and editing.
- **Schema evolution safety.** Field/variant numbers are permanent identifiers;
  removed numbers get `removed` markers and must never be reused; unrecognized
  extra fields coming from a newer schema version are preserved verbatim during
  a round-trip.
- **Native feel.** Each generator must produce code that looks idiomatic for its
  language: camelCase in TypeScript/Java/Kotlin, snake_case in Python/C++,
  builder pattern in Java, data-class-like in Kotlin, etc.

---

## 2. Schema Language Reference

### 2.1 File layout

- Extension: `.skir`
- Source root: the `skir.yml` file in the project states where the `.skir` files
  live (conventionally `skir-src/`).
- Generated output goes into a configured output directory (conventionally
  `skirout/`).
- One or many `.skir` files; each file is one **module**. Imports reference other
  modules.

### 2.2 Records

A **record** is either a `struct` or an `enum`. All records at the top level of a
file are exported by the generator for that module. Records can be nested inside
other records purely for namespacing (the generated code is identical whether the
nesting is explicit or inline).

#### Structs

```skir
struct Point {
  x: int32;      // implicit field number = 0
  y: int32;      // = 1
  label: string; // = 2
}
```

- Field numbers can be explicit (`x: int32 = 0;`) or implicit (sequential from 0).
- Field names are `snake_case`.
- **Removed fields**: When removing a field, mark it `removed;` (implicit) or
  `removed 2..4, 6;` (explicit). Removed numbers must **never** be reused.
- **Stable identifier** (optional): `struct Point(23456) { ... }` assigns a
  numeric record ID used by the snapshot/schema-evolution tooling.
- **Recursive structs**: a struct can contain a field of its own type (directly
  or indirectly). The generated code must prevent accidental direct
  self-containment at compile time (e.g., using a heap-allocated indirection).

#### Enums

```skir
enum SubscriptionStatus {
  free;                    // constant variant, implicit number = 1
  trial: Trial;            // wrapper variant, number = 2
  premium;                 // constant variant, number = 3

  struct Trial {
    start_time: timestamp;
  }
}
```

- Implicit numbering starts at **1** (0 is always reserved for UNKNOWN).
- Two kinds of variants:
  - **Constant variant**: ALL_CAPS name; holds no data.
  - **Wrapper variant**: lowercase name; holds a value of some type.
- The special **UNKNOWN** variant (number 0) is implicit in every enum and does
  not need to be written in the schema. It represents "value received from a
  newer version of the schema that this code does not recognize".
- Variants (like struct fields) can be removed with `removed;` / `removed N;`.

#### Nesting

Records can be defined inside other records:

```skir
struct User {
  struct Pet {
    name: string;
    picture: string;
  }
  pets: [Pet];
}
```

References use dot notation: `User.Pet`. In generated code, nesting is expressed
using the language's nested-class / inner-class mechanism (TypeScript uses `_`
separators in class names and re-exports through namespaces; Java/Kotlin use
nested classes; Python uses inner classes; Dart/C++ use name mangling like
`User_Pet`).

#### Inline records

```skir
struct Notification {
  payload: enum {
    PUSH;
    email: struct { subject: string; body: string; }
  }
}
```

Inline records behave identically to explicitly named nested records. The
compiler infers the type name by converting the `snake_case` field name to
`PascalCase`. Inline records **cannot** be wrapped in `[...]` or `?` directly —
name the type explicitly in those cases.

### 2.3 Data Types

| Skir type  | Description |
|-----------|-------------|
| `bool`    | Boolean |
| `int32`   | Signed 32-bit integer |
| `int64`   | Signed 64-bit integer |
| `hash64`  | Unsigned 64-bit integer (preferred for identifiers / hash codes) |
| `float32` | IEEE 754 single-precision; supports NaN, Infinity, -Infinity |
| `float64` | IEEE 754 double-precision; supports NaN, Infinity, -Infinity |
| `string`  | UTF-8 string |
| `bytes`   | Raw bytes |
| `timestamp` | Milliseconds since Unix epoch, range ±100M days |
| `T?`      | Optional — either a `T` or null |
| `[T]`     | Ordered array of `T` |
| `[T\|key]` | Keyed array (see below) |
| Any struct or enum type | Record |

#### Keyed arrays

`[T|key_field]` flags that each element's `key_field` uniquely identifies it, so
lookup-by-key is generated. If the key is in a nested struct, chain field names:
`[T|a.b.c]`. If the key is an **enum**, append `.kind` to the chain:
`[WorkStatus|weekday.kind]`. The key type must be a primitive or an enum (not
another struct).

### 2.4 Constants

```skir
const PI: float64 = 3.14159;
const TARZAN: User = {
  user_id: 123,
  name: "Tarzan",
  pets: [{ name: "Cheeta", height_in_meters: 1.67, picture: "🐒" }],
  subscription_status: { kind: "trial", value: { start_time: "2025-04-02T11:13:29Z" } },
  quote: "AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA",
};
```

- Constants are expressed in a JSON-like syntax (unquoted keys, trailing commas,
  single or double quotes for strings, multi-line strings with `\` continuation).
- Use `{| ... |}` instead of `{ ... }` to allow missing fields (they default to
  their type's default value).
- Enum constants: use the string name for constant variants (`"FREE"`), or
  `{ kind: "...", value: ... }` for wrapper variants.
- Array constants: `["en-GB", "en-US"]`.
- Constants are stored in the generated code by deserializing from dense JSON at
  module initialization time.

### 2.5 Methods (RPC API)

```skir
method GetUser(GetUserRequest): GetUserResponse = 12345;
```

- Every method has a **stable numeric identifier** that cannot change; it is used
  by the RPC router to identify the method regardless of name changes.
- Inline request/response records are supported (the compiler appends `Request`
  / `Response` to the method name).
- Methods may be defined in any `.skir` file; they are commonly in their own
  `service.skir` file.

### 2.6 Imports

```skir
import { User, Pet } from "user.skir";
import * as geometry from "geometry/shapes.skir";

struct Order {
  customer: User;
  location: geometry.Point;
}
```

- Import paths are relative to the Skir source root, not the current file.
- External packages (published on GitHub) can also be imported; the Skir package
  manager resolves them.

### 2.7 Doc comments

```skir
/// A registered user of the system.
struct User {
  user_id: int32;
  /// A personal quote or motto.
  quote: string;
}
```

- Triple-slash `///` doc comments. They are propagated verbatim into the
  generated code (as JSDoc, Python docstrings, Javadoc, KDoc, etc.).
- References: `[FieldName]` or `[TypeName.FieldName]` inside a doc comment
  produce a compile error if the referenced symbol doesn't exist.

---

## 3. Serialization Format

The client library is responsible for implementing all three formats. The
generated code delegates entirely to the client library for serialization.

### 3.1 Dense JSON (default format — safe for persistence)

Structs are encoded as **JSON arrays** where the array index equals the field
number. Enum constant variants are encoded as integers; wrapper variants as
two-element arrays.

**Encoding rules:**

| Type | Dense JSON encoding |
|------|---------------------|
| `bool` | `1` (true) or `0` (false) |
| `int32` | JSON number |
| `int64`, `hash64` | JSON number if value is within the JS safe integer range (−9,007,199,254,740,991 … +9,007,199,254,740,991); otherwise a JSON string |
| `float32`, `float64` | JSON number for finite values; `"NaN"`, `"Infinity"`, `"-Infinity"` as JSON strings |
| `timestamp` | JSON number: milliseconds since Unix epoch |
| `string` | JSON string |
| `bytes` | Base64-encoded JSON string |
| `T?` | `null` if absent; otherwise the encoded value |
| `[T]` | JSON array of encoded elements |
| `struct` | JSON array; index = field number; removed fields = `0`; **trailing default-value fields are omitted** |
| `enum` (constant) | The variant's integer number |
| `enum` (wrapper) | `[number, encoded_value]` |
| `enum` (UNKNOWN) | `0` (or the unrecognized integer/array if `keep_unrecognized_values` is enabled) |

**Key struct encoding detail:** The array length is determined by scanning fields
from the last to the first and stopping at the first non-default value. Only the
necessary prefix of the field array is emitted:

```
struct User { user_id: int32; name: string; quote: string; }
// If user_id=42, name="John", quote="" (default) → [42,"John"]
// If user_id=0 (default), name="John", quote="" → [0,"John"]  (removed: trailing default stripped, middle zero kept)
// If everything is default → []
```

**Handling zeros during deserialization:** `0` (integer zero) is treated as a
valid input for any type and decodes to that type's default value. This is used
for removed fields. Exception: for optional types (`T?`), `0` decodes as the
*inner type's* default value, **not** as null (null is represented by an explicit
JSON `null`).

**Both dense and readable JSON are accepted during deserialization** — the parser
auto-detects based on whether the outer container is an array (dense) or an
object (readable).

### 3.2 Readable JSON (for debugging only — not safe for persistence)

Structs are encoded as JSON **objects** with `snake_case` field names. Default
fields are omitted. **Do not store readable JSON long-term** because field
renames in the schema would make old data unreadable.

**Encoding rules:**

| Type | Readable JSON encoding |
|------|------------------------|
| `bool` | `true` / `false` |
| `int32` | JSON number |
| `int64`, `hash64` | Same safe-integer rule as dense JSON |
| `float32`, `float64` | JSON number; strings for NaN/Infinity/-Infinity |
| `timestamp` | Object: `{ "unix_millis": 1672531200000, "formatted": "2023-01-01T00:00:00Z" }` |
| `string` | JSON string |
| `bytes` | `"hex:"` followed by hex digits, e.g. `"hex:48656c6c6f"` |
| `T?` | `null` or the encoded value |
| `[T]` | JSON array |
| `struct` | JSON object with `snake_case` keys; missing = default |
| `enum` (constant) | The variant name as a string, e.g. `"FREE"` |
| `enum` (wrapper) | `{ "kind": "trial", "value": { ... } }` |
| `enum` (UNKNOWN) | `"UNKNOWN"` |

### 3.3 Binary format

Little-endian byte order throughout. More compact than JSON; faster to
parse/emit in C++. Prefer JSON unless performance is critical.

| Type | Encoding |
|------|----------|
| `bool` | `0x01` (true) or `0x00` (false) |
| `int32` | Variable-length: 0–231 → 1 byte; 232–65535 → `0xe8` + uint16; ≥65536 → `0xe9` + uint32; −256 to −1 → `0xeb` + uint8; −65536 to −257 → `0xec` + uint16; ≤−65537 → `0xed` + int32 |
| `int64` | If fits in int32, uses int32 encoding; otherwise `0xee` + 8 bytes (int64 LE) |
| `hash64` | If fits in uint32, uses int32 encoding; otherwise `0xea` + 8 bytes (uint64 LE) |
| `float32` | `0` → `0x00`; otherwise `0xf0` + 4 bytes (IEEE 754 LE) |
| `float64` | `0` → `0x00`; otherwise `0xf1` + 8 bytes (IEEE 754 LE) |
| `timestamp` | Epoch → `0x00`; otherwise `0xef` + 8 bytes (int64 millis LE) |
| `string` | Empty → `0xf2`; non-empty → `0xf3` + length (as int32 encoding) + UTF-8 bytes |
| `bytes` | Empty → `0xf4`; non-empty → `0xf5` + length (as int32) + raw bytes |
| `T?` | Null → `0xff`; present → encoded value |
| `[T]` (0 items) | `0xf6` |
| `[T]` (1 item) | `0xf7` + item |
| `[T]` (2 items) | `0xf8` + items |
| `[T]` (3 items) | `0xf9` + items |
| `[T]` (>3 items) | `0xfa` + length (as int32) + items |
| `struct` | Same as `[T]` (field number = array index; trailing defaults omitted) |
| `enum` (constant 0) | `0x00` |
| `enum` (constant N) | Encoded as int32 (N) |
| `enum` (wrapper N=1) | `0xfb` + encoded value |
| `enum` (wrapper N=2) | `0xfc` + encoded value |
| `enum` (wrapper N=3) | `0xfd` + encoded value |
| `enum` (wrapper N=4) | `0xfe` + encoded value |
| `enum` (wrapper N>4) | `0xf8` + N (as int32) + encoded value |

### 3.4 Type descriptors (reflection)

Every serializer exposes a type descriptor that describes the schema of the type
in a language-agnostic, serializable JSON form. The format:

```json
{
  "type": { "kind": "record", "value": "user.skir:User" },
  "records": [
    {
      "kind": "struct",
      "id": "user.skir:User",
      "doc": "A user",
      "fields": [
        { "name": "user_id", "number": 0, "type": { "kind": "primitive", "value": "int32" } },
        { "name": "pets",    "number": 3, "type": { "kind": "array", "value": { "item": { "kind": "record", "value": "user.skir:User.Pet" }, "key_chain": "name" } } }
      ]
    },
    {
      "kind": "enum",
      "id": "user.skir:SubscriptionStatus",
      "variants": [
        { "name": "FREE",    "number": 1 },
        { "name": "PREMIUM", "number": 3 },
        { "name": "trial",   "number": 2, "type": { "kind": "record", "value": "user.skir:SubscriptionStatus.Trial" } }
      ]
    }
  ]
}
```

Record IDs are of the form `"{module_filename}:{TypeName}"`. For nested types:
`"user.skir:User.Pet"`. The `records` array includes all transitively referenced
records.

---

## 4. Unrecognized Fields & Schema Evolution

A core design principle is that a client compiled with schema version N can
receive data written by schema version N+1 (which may have added new fields or
variants) and must not lose that extra data on a round-trip.

- Every generated struct stores unrecognized fields in an internal
  `_unrecognized` / `_u` slot.
- Every generated enum stores unrecognized variants with their number and encoded
  bytes in an internal slot.
- When the `keep_unrecognized_values` option is enabled in the service, these
  fields are preserved during deserialization and re-emitted during
  serialization. When disabled (the default for most client uses), unrecognized
  data is silently dropped.
- The array length seen in the serialized form is stored (for both dense JSON and
  binary) so that it can be faithfully re-emitted even if no recognized field
  occupied the last position.

---

## 5. RPC Protocol

### 5.1 Request wire format

The service endpoint receives a **body string** (either as the HTTP body for POST
requests, or as the URL-decoded query string for GET requests):

```
{method_name}:{method_number}:{json_flavor}:{dense_json_body}
```

- `method_name`: the human-readable method name (for debugging only; routing is
  done by number).
- `method_number`: the stable numeric identifier from the schema.
- `json_flavor`: `dense` or `readable` (indicates how the request body is
  encoded; all Skir clients use dense JSON).
- `dense_json_body`: the dense JSON encoding of the request struct.

Example body: `GetUser:12345:dense:[123]`

### 5.2 Response

- HTTP 200 + the dense JSON encoding of the response struct as the body, with
  `Content-Type: application/json`.
- HTTP 400 for malformed requests (method not found, parse error).
- HTTP 500 for server-side handler errors.
- The service handler can also return typed error codes (e.g., 403 Forbidden, 404
  Not Found) when using the `ErrorOr<Response>` return pattern (C++) or
  equivalent.

### 5.3 Method listing endpoint

`GET {endpoint}?list` returns a JSON object listing all declared methods:

```json
{ "methods": [ { "name": "GetUser", "number": 12345 }, ... ] }
```

### 5.4 Service architecture

The service is **framework-agnostic** at the core: it receives a raw string body
and metadata (e.g., HTTP headers) and returns a `RawResponse { status_code, content_type, data }`.
The framework-specific glue (Express, FastAPI, Flask, Spring, httplib, etc.)
wraps this interface. The generated code does **not** contain HTTP logic; that is
entirely the client library's domain.

---

## 6. Code Generation — Language-Specific Principles

### 6.1 Common principles (all languages)

1. **One output file per input module.** The filename is derived from the module
   name of the `.skir` file. Imports between modules become imports in the
   generated code.
2. **Generated files carry a header banner** identifying that they are generated,
   not hand-edited. The banner includes the generator name, a link to the
   generator repository, and instructions for installing the client library.
3. **Field names**: all generated languages use the exact schema field name (no
   conversion) for serialization purposes. In the **reading/writing API** (i.e.,
   how a user accesses fields), conversions to the language's convention are
   applied (camelCase for TypeScript/Java/Kotlin, unchanged snake_case for
   Python/C++/Dart).
4. **All struct fields are required by default.** A "partial" / "default"
   construction mode allows omitting fields, in which case they take their
   default values (0 / "" / false / UNKNOWN / [] / null for optionals / empty
   struct for struct fields).
5. **Constants**: generated as lazily initialized, read-only values deserialized
   from their dense JSON representation at module initialization time.
6. **Nested types**: the generated name combines parent and child names with a
   language-appropriate separator.
7. **Recursive types**: use heap-allocated indirections compile-time. The
   generator must detect cycles and wrap recursive field types in a smart
   pointer / lazy reference pattern.
8. **Doc comments** from the schema are copied to the relevant generated element.

---

### 6.2 TypeScript

#### Files produced

For a schema module named `user.skir`:
- `user.js` — runtime implementation
- `user.d.ts` — TypeScript type declarations

The `.js` file begins with `/// <reference types="./user.d.ts" />`.

#### Client library import

```typescript
import * as $ from "skir-client";
```

All base classes, serializer plumbing, and utilities come from `skir-client`
(npm package).

#### Struct generation

```typescript
// Frozen (immutable) class
export class User extends $._FrozenBase {}
// Mutable class
class User_Mutable { ... }
// Types exported under the namespace for nested access
export namespace User {
  export type Mutable = User_Mutable;
  export type OrMutable = User | Mutable;
  export type Pet = User_Pet;  // nested type alias
}
```

- Frozen class extends `$._FrozenBase` (same for nested/inner types).
- The frozen class itself is essentially empty — all property declarations are in
  the `.d.ts` file.
- Properties are `readonly` in the `.d.ts`.
- `static create<_W extends "whole"|"partial" = "whole">(init: Initializer<_W>): T`
  — strict form requires all fields; `create<"partial">` allows omission.
- `static readonly DEFAULT: T` — all-default instance.
- `static readonly serializer: $.Serializer<T>`.
- `static readonly Mutable: typeof T_Mutable` — reference to the mutable class.
- `toFrozen(): this` — no-op on frozen; returns `this`.
- `toMutable(): T.Mutable` — cheap shallow copy.

Mutable class:
- Plain class (no special base).
- Constructor: `constructor(init?: Partial<Initializer>)` — all fields optional.
- Properties are writable.
- `mutableX` getter for struct/array fields: lazy-upgrades the property to a
  mutable version and returns it.
- `toFrozen(): T` — deeply freezes (recursively converts nested mutable values).

#### Enum generation

```typescript
export class SubscriptionStatus extends $._EnumBase {}
export namespace SubscriptionStatus {
  export type Kind = "UNKNOWN" | "FREE" | "trial" | "PREMIUM";
  export type Initializer = SubscriptionStatus | "UNKNOWN" | "FREE" |
    { kind: "trial"; value: Trial.Initializer } | "PREMIUM";
  export type UnionView =
    | { kind: "UNKNOWN"; value: undefined }
    | { kind: "FREE"; value: undefined }
    | { kind: "trial"; value: Trial }
    | { kind: "PREMIUM"; value: undefined };
}
```

- Constant variants are `static readonly FREE: SubscriptionStatus`.
- `static readonly UNKNOWN: SubscriptionStatus`.
- `static create(init: Initializer): SubscriptionStatus` — accepts the constant
  instance itself, a string name, or `{ kind, value }` for wrappers.
- `declare readonly union: UnionView` — the user accesses `union.kind` and
  `union.value` to pattern-match.

#### Methods

```typescript
export const GetUser: $.Method<GetUserRequest, GetUserResponse>;
// .js:
export const GetUser = /*@__PURE__*/ (() => ({
  name: "GetUser",
  number: 12345,
  requestSerializer: GetUserRequest.serializer,
  responseSerializer: GetUserResponse.serializer,
  doc: "",
}))();
```

#### Module initialization

All struct/enum metadata is registered together in a single call at the bottom of
the `.js` file:

```javascript
$._initModuleClasses("user.skir", [
  {
    kind: "struct",
    ctor: User_Pet,
    initFn: initUserPet,
    name: "Pet",
    parentCtor: User, // for nested types
    doc: "...",
    fields: [
      { name: "name", property: "name", number: 0, type: { kind: "primitive", primitive: "string" } },
      { name: "height_in_meters", property: "heightInMeters", number: 1, type: { kind: "primitive", primitive: "float32" } },
    ],
  },
  {
    kind: "struct",
    ctor: User,
    initFn: initUser,
    name: "User",
    fields: [
      { name: "pets", property: "pets", number: 3, type: { kind: "array", item: { kind: "record", ctor: User_Pet }, keyChain: "name" }, mutableGetter: "mutablePets", indexable: { searchMethod: "searchPets", keyFn: (v) => v.name } },
    ],
  },
  {
    kind: "enum",
    ctor: SubscriptionStatus,
    createValueFn: createValueOfSubscriptionStatus,
    name: "SubscriptionStatus",
    variants: [
      { name: "UNKNOWN", number: 0 },
      { name: "FREE", number: 1 },
      { name: "trial", number: 2, type: { kind: "record", ctor: SubscriptionStatus_Trial } },
      { name: "PREMIUM", number: 3 },
    ],
  },
]);
```

Field descriptor `type` values:
- Primitive: `{ kind: "primitive", primitive: "int32" | "int64" | "hash64" | "float32" | "float64" | "bool" | "string" | "bytes" | "timestamp" }`
- Record: `{ kind: "record", ctor: TheClass }`
- Array: `{ kind: "array", item: <type>, keyChain?: "field_name" }`
- Optional: `{ kind: "optional", other: <type> }`

Array fields that support keyed lookup also have `indexable: { searchMethod: "searchFoo", keyFn: (item) => item.fieldName }`.

Fields that have a mutable-upgrade getter (struct or array fields) carry `mutableGetter: "mutableFoo"`.

#### Constants in .js

```javascript
export const TARZAN = /*@__PURE__*/ User.serializer.fromJson([123,"Tarzan",...]);
```

#### Field naming convention

Schema `snake_case` → TypeScript `camelCase`:
- `user_id` → `userId`; `height_in_meters` → `heightInMeters`; `start_time` → `startTime`.

#### Optional fields

- Frozen: `readonly user: User | null`
- Mutable: `user: User.OrMutable | null`
- In mutable class: `get mutableUser(): User.Mutable` — returns a mutable version.
  But only if the field is non-null; if the value is null, this getter doesn't exist
  conceptually (you just assign a new value).

---

### 6.3 Python

#### File produced

`{module_name}_skir.py` (e.g., `user_skir.py` for `user.skir`).

#### Client library import

```python
import skir
from skir import _, _module_initializer, _spec
```

The `_` sentinel is used as a placeholder for values that are initialized at
module-load time by `_module_initializer.init_module(...)`.

#### Struct generation

```python
@typing.final
class User:
    """Deeply immutable. If you need mutability, use 'User.Mutable'."""

    def __init__(
        _self,
        *,
        user_id: int,       # ALL fields required as keyword-only args
        name: str,
        pets: collections.abc.Iterable["User.Pet.OrMutable"],
        subscription_status: "SubscriptionStatus",
    ):
        ...   # implementation by _module_initializer

    @staticmethod
    def partial(
        *,
        user_id: int = 0,
        name: str = "",
        pets: collections.abc.Iterable["User.Pet.OrMutable"] = (),
        subscription_status: "SubscriptionStatus" = _,  # default = UNKNOWN
    ) -> "User": ...

    def replace(
        _self,
        *,
        user_id: int | skir.Keep = skir.KEEP,
        name: str | skir.Keep = skir.KEEP,
        # ... all fields
    ) -> "User": ...

    @property
    def user_id(self) -> int: ...
    @property
    def pets(self) -> tuple["User.Pet", ...]: ...  # stored as tuple (immutable)

    def to_frozen(self) -> "User": ...  # no-op
    def to_mutable(self) -> "User.Mutable": ...

    @typing.final
    class Mutable:
        def __init__(_self, *, user_id: int = 0, name: str = "", ...): ...
        user_id: int    # mutable attributes (not properties)
        name: str
        @property
        def mutable_pets(self) -> list["User.Pet.OrMutable"]: ...  # lazy upgrade
        def to_frozen(self) -> "User": ...

    OrMutable: typing.TypeAlias = "User | User.Mutable"
    DEFAULT: typing.Final["User"] = _
    serializer: typing.Final[skir.Serializer["User"]] = _

    @typing.final
    class Pet:
        ...  # nested struct, same pattern
```

Key Python-specific details:
- Field names remain **snake_case** (no conversion).
- Properties returned from frozen structs: arrays → `tuple[T, ...]`; struct fields
  → the frozen struct type.
- `Mutable` class has direct attribute access (no `@property`), except for
  `mutable_x` properties that perform a lazy upgrade.
- `mutable_x` property: checks if the current value is already a list (for
  arrays) or a Mutable (for struct fields); if so returns it; otherwise replaces
  it with a mutable shallow copy and returns that.
- `OrMutable` is a type alias, not a class.
- `DEFAULT` is a class attribute initialized to `partial()`.
- Frozen constructor (`__init__`) takes all fields as keyword-only. The first
  argument is named `_self` (not `self`) to avoid collision if there is a field
  also named `self` — this is a Skir convention.
- `replace()` uses `skir.KEEP` as a sentinel for "don't change this field".

#### Enum generation

```python
@typing.final
class SubscriptionStatus:
    UNKNOWN: typing.Final["SubscriptionStatus"] = _
    FREE: typing.Final["SubscriptionStatus"] = _
    PREMIUM: typing.Final["SubscriptionStatus"] = _

    @staticmethod
    def wrap_trial(value: "SubscriptionStatus.Trial.OrMutable") -> "SubscriptionStatus": ...
    @staticmethod
    def create_trial(*, start_time: skir.Timestamp) -> "SubscriptionStatus": ...
    # create_* is a shortcut that calls wrap_* with a newly constructed struct

    Kind: typing.TypeAlias = typing.Literal["UNKNOWN", "FREE", "trial", "PREMIUM"]

    @property
    def union(self) -> "SubscriptionStatus._Unknown | SubscriptionStatus._FREE | ...": ...

    class _Unknown(typing.Protocol):
        @property
        def kind(self) -> typing.Literal["UNKNOWN"]: ...
        @property
        def value(self) -> None: ...

    class _trial(typing.Protocol):
        @property
        def kind(self) -> typing.Literal["trial"]: ...
        @property
        def value(self) -> "SubscriptionStatus.Trial": ...

    serializer: typing.Final[skir.Serializer["SubscriptionStatus"]] = _

    @typing.final
    class Trial: ...  # nested struct for wrapper variant
```

Pattern matching is done via `status.union.kind == "..."` and
`status.union.value` for wrapper variants. For exhaustive matching use `Never`:

```python
def f(status: SubscriptionStatus) -> str:
    if status.union.kind == "FREE": return "free"
    elif status.union.kind == "trial": return f"trial since {status.union.value.start_time}"
    elif status.union.kind == "PREMIUM": return "premium"
    elif status.union.kind == "UNKNOWN": return "unknown"
    _: Never = status.union.kind  # static error if a case is missed
    raise AssertionError("unreachable")
```

#### Optional fields (Python)

- Frozen: `user: "SomeType | None"` (standard Python nullable)
- Mutable: same, plus `mutable_user` property to get mutable version

#### Keyed arrays (Python)

- The property returns `skir.KeyedItems[ItemType, KeyType]` which is a
  `tuple`-like type with `.find(key) -> T | None` and
  `.find_or_default(key) -> T` methods.
- In `Mutable`, the field is a `list["T.OrMutable"]`.

#### Methods (Python)

```python
GetUser: typing.Final[skir.Method["GetUserRequest", "GetUserResponse"]] = _
AddUser: typing.Final[skir.Method["AddUserRequest", "AddUserResponse"]] = _
```

Methods are top-level module attributes initialized by `_module_initializer`.

#### Module initialization

All metadata is declared at the bottom of the file:

```python
_module_initializer.init_module(
    records=(
        _spec.Struct(
            id="user.skir:User",
            fields=(
                _spec.Field(name="user_id", number=0, type=_spec.PrimitiveType.INT32),
                _spec.Field(name="name", number=1, type=_spec.PrimitiveType.STRING),
                _spec.Field(name="pets", number=3, type=_spec.ArrayType("user.skir:User.Pet"), has_mutable_getter=True),
                _spec.Field(name="subscription_status", number=4, type="user.skir:SubscriptionStatus"),
            ),
        ),
        _spec.Enum(
            id="user.skir:SubscriptionStatus",
            constant_variants=(_spec.ConstantVariant(name="FREE", number=1), _spec.ConstantVariant(name="PREMIUM", number=3)),
            wrapper_variants=(_spec.WrapperVariant(name="trial", number=2, type="user.skir:SubscriptionStatus.Trial"),),
        ),
        _spec.Struct(id="user.skir:SubscriptionStatus.Trial", fields=(...)),
    ),
    methods=(
        _spec.Method(name="GetUser", number=12345, request_type="...", response_type="..."),
    ),
    constants=(
        _spec.Constant(name="TARZAN", type="user.skir:User", json_code='[123,"Tarzan",...]'),
    ),
    globals=globals(),
)
```

The `_spec.PrimitiveType` enum has: `BOOL`, `INT32`, `INT64`, `HASH64`,
`FLOAT32`, `FLOAT64`, `STRING`, `BYTES`, `TIMESTAMP`.

Composite type specs:
- `_spec.ArrayType(item_record_id)` or `_spec.ArrayType(item_record_id, ("key_field",))`
- `_spec.OptionalType(item_record_id_or_primitive_type)`
- Struct field types: primitive type enum member, string (record ID), or
  composite type spec.

`has_mutable_getter=True` must be set for struct fields and array fields of
struct type (so the mutable class gets the `mutable_x` property).

---

### 6.4 C++

#### Files produced

For `user.skir`:
- `skirout/user.h` — type definitions and declarations
- `skirout/user.cc` — serialization/deserialization logic
- `skirout/user.testing.h` — gmock matchers (optional testing support)

The skirout directory in the output folder mirrors the module path.

#### Client library (header + implementation)

The entire C++ client library is `skir.h` and `skir.cc`. Generated files include
`skir.h`:

```cpp
#include "skir.h"
```

#### Namespace layout

- Shared getter functors live in `namespace skirout`.
- Actual types live in `namespace skirout_{module_name}` (e.g., `skirout_user`).
  For deeply nested modules the namespace uses underscores.
- Type aliases (`using Pet = User_Pet;`) are defined inside the parent struct.
- Constants: `const User& k_tarzan();` — a function returning a static instance.

#### Struct generation (C++)

Structs are plain mutable aggregate types:

```cpp
namespace skirout_user {

struct User {
  std::string name;
  std::vector<User_Pet> pets;
  std::string quote;
  SubscriptionStatus subscription_status;
  int64_t user_id = 0;  // NOTE: int32 in schema, stored as int64 in C++

  skir_internal::UnrecognizedFields<skir_internal::skirout_user::UserAdapter> _unrecognized;

  bool operator==(const User&) const;
  bool operator!=(const User& other) const { return !(*this == other); }

  // Aggregate-initializer that forces all fields to be specified:
  struct whole {
    skir::must_init<std::string> name;
    skir::must_init<std::vector<User_Pet>> pets;
    skir::must_init<std::string> quote;
    skir::must_init<SubscriptionStatus> subscription_status;
    skir::must_init<int64_t> user_id;
    operator User();
  };

  using Pet = User_Pet;  // nested type alias
};

}  // namespace skirout_user
```

Key C++ specifics:
- Structs are **mutable by default** (C++ philosophy); no frozen/mutable split.
  Immutability is the caller's responsibility (use `const`).
- Fields are **alphabetically sorted** (not in schema declaration order) in the
  struct definition — this is a C++ generator convention.
- Field names are **snake_case** (unchanged from schema).
- Integer types: `int32` → `int64_t` (C++ uses 64-bit storage for all integer
  fields for simplicity / future-proofing). Serialization still uses the correct
  wire format.
- Arrays: `std::vector<T>` for non-keyed; `skir::keyed_items<T, KeyFn>` for
  keyed arrays.
- Optional: `std::optional<T>` (or `absl::optional<T>`).
- Recursive types: `skir::rec<T>` — a lazy heap-allocated reference that prevents
  infinite struct size.
- `struct whole { ... }` provides compile-time completeness checking; missing
  fields produce a compile error because `must_init<T>` wraps the field and
  has no default constructor.
- `operator==(...)` and `operator!=(...)` for value equality.
- `std::ostream& operator<<(...)` for debug printing (delegates to
  `skir_internal::ToDebugString`).
- `AbslHashValue(H h, const T& input)` for Abseil hash support (on structs with
  all hashable fields).

#### Enum generation (C++)

```cpp
class SubscriptionStatus {
 public:
  enum class kind_type {
    kUnknown,
    kFreeConst,
    kPremiumConst,
    kTrialWrapper,
  };

  SubscriptionStatus(skirout::k_unknown = skirout::kUnknown);
  SubscriptionStatus(skirout::k_free);
  SubscriptionStatus(skirout::k_premium);
  SubscriptionStatus(wrap_trial_type);  // wrap_trial<T> template

  static SubscriptionStatus wrap_trial(SubscriptionStatus_Trial value);

  kind_type kind() const;
  bool is_trial() const;
  const SubscriptionStatus_Trial& as_trial() const;
  SubscriptionStatus_Trial& as_trial();

  template <typename Visitor>
  decltype(auto) visit(Visitor&& v) const { ... }  // calls v with the appropriate tag/wrapper

  bool operator==(const SubscriptionStatus&) const;

  using Trial = SubscriptionStatus_Trial;

  static constexpr auto kUnknown  = skirout::kUnknown;
  static constexpr auto kFree     = skirout::kFree;
  static constexpr auto kPremium  = skirout::kPremium;
};
```

Key C++ enum specifics:
- The enum class is not a `std::variant`; it uses a tagged union internally.
- **Tag types** are global sentinel structs in `namespace skirout` (shared across
  all modules): `k_unknown`, `k_free`, `k_premium`, etc. They are named after the
  variant names. Constant tags are ALL_CAPS → `kFree`, `kPremium` etc (because
  free-standing tag types live in the `skirout` namespace with `k_` prefix).
- `wrap_X<T>` is a template struct defined in `namespace skirout` as a guard
  against name collisions.
- Visitor pattern: `e.visit(visitor_obj)` where the visitor has overloaded
  `operator()` for each variant. Constant variants receive the tag type;
  wrapper variants receive the `wrap_X` struct.
- `is_X()` / `as_X()` convenience accessors for single-variant checks.
- The `#ifndef` guards for shared tag types prevent redefinition across modules.

#### Getter functors (C++)

For each field name defined in any module, a functor template is generated in
`namespace skirout` (with `#ifndef` guards for deduplication):

```cpp
namespace skirout {
#ifndef skirout_get_user_id
#define skirout_get_user_id
template <typename other = skir::identity>
struct get_user_id {
  static constexpr absl::string_view kFieldName = "user_id";
  template <typename T>
  auto& operator()(T& input) const {
    return skir_internal::get(other()(input).user_id);
  }
};
#endif
}
```

These are used as the `KeyFn` template argument in `skir::keyed_items<T, KeyFn>`.

#### Testing header (C++)

`user.testing.h` provides gmock matchers:

```cpp
// Usage:
EXPECT_THAT(actual, ::testing::skirout::StructIs<User>{
  .name = "Alice",
  .user_id = 42,
});
```

The `StructIs<T>` matcher is an aggregate struct mirroring the struct fields but
with `Matcher<FieldType>` field types.

#### Constants (C++)

```cpp
const User& k_tarzan() {
  static const auto* kResult = new User(
    skir::Parse<User>("[123,\"Tarzan\",...]").value()
  );
  return *kResult;
}
```

#### Methods (C++)

In `skirout/methods.h`:

```cpp
namespace skirout_methods {

struct GetUser {
  static constexpr int kNumber = 12345;
  static constexpr absl::string_view kName = "GetUser";
  using request_type = GetUserRequest;
  using response_type = GetUserResponse;
  // Serializer/deserializer functions provided by skir.h
};

}  // namespace skirout_methods
```

Usage:

```cpp
auto response = skir::service::InvokeRemote(
    *client, skirout_methods::GetUser{},
    GetUserRequest{ ... }, options);
```

---

### 6.5 Java

#### Files produced

One `.java` file per generated type, in `src/main/java/skirout/{module_name}/`.

- Structs → `StructName.java`
- Enums → `EnumName.java`
- Constants → `Constants.java`
- Methods → `Methods.java`

#### Client library

```gradle
implementation("build.skir:skir-client:latest.release")
```

Packages: `build.skir.*`, `build.skir.internal.*`, `build.skir.reflection.*`,
`build.skir.service.*`.

#### Struct generation (Java)

```java
package skirout.user;

/** Deeply immutable. */
public final class User {
  // Private fields
  private final String name;
  private final List<Pet> pets;
  private final SubscriptionStatus subscriptionStatus;
  private final int userId;  // int for int32, long for int64/hash64
  private final build.skir.internal.UnrecognizedFields<User> _u;

  // Getter methods (camelCase, no 'get' prefix)
  public String name() { return this.name; }
  public List<Pet> pets() { return this.pets; }
  public SubscriptionStatus subscriptionStatus() { return this.subscriptionStatus; }
  public int userId() { return this.userId; }

  /** Constants */
  public static final User DEFAULT = new User();

  /** Serializer */
  public static final build.skir.Serializer<User> SERIALIZER = ...;

  /** Reflection */
  public static final build.skir.reflection.StructDescriptor.Reflective<User, User.Builder> TYPE_DESCRIPTOR = ...;

  /** Phased builder (if fields count > 0) */
  public interface Builder_AtName     { Builder_AtPets setName(String name); }
  public interface Builder_AtPets     { Builder_AtSubscriptionStatus setPets(List<Pet> pets); }
  // ... one interface per field, in alphabetical order
  public interface Builder_Done       { User build(); }

  public static Builder_AtName builder() { return new Builder(); }
  public static Builder partialBuilder() { return new Builder(); }
  public Builder toBuilder() { ... }
  public static final class Builder implements Builder_AtName, Builder_AtPets, ..., Builder_Done {
    public Builder setName(String name) { this.name = Objects.requireNonNull(name); return this; }
    public Builder updateName(Function<? super String, ? extends String> f) { ... }
    // ... for each field
    public User build() { ... }
  }

  @Override public boolean equals(Object other) { ... }
  @Override public int hashCode() { ... }
  @Override public String toString() { return SERIALIZER.toJsonCode(this, JsonFlavor.READABLE); }

  // Nested types
  public static final class Pet { ... }
}
```

Key Java specifics:
- **Phased builder**: `builder()` returns `Builder_AtFieldName` where `FieldName`
  is the first field alphabetically. Each `setX()` returns the interface for the
  next field in alphabetical order; when all required fields are set the result
  is `Builder_Done` which exposes `build()`. This enforces all required fields at
  compile time.
- **`partialBuilder()`**: returns a plain `Builder` directly, allowing fields to
  be set in any order without compile-time enforcement.
- **`toBuilder()`**: creates a builder initialized with the current field values.
- **`updateX(Function<T,T> f)`**: helper on Builder that calls `setX(f.apply(currentX))`.
- Field names: Java `camelCase` (same as TypeScript).
- Integer types: `int` for `int32`; `long` for `int64`/`hash64`.
- Optional fields: `Optional<T>`.
- Array fields contain `List<T>` (unmodifiable). Keyed arrays return a special
  `List<T>` subtype with `findByKey(key)` returning null or the last matching element.
- `equals` implemented via `Arrays.deepEquals` on an `_equalsProxy()` array.
- `toString` returns readable JSON.

#### Enum generation (Java)

Java enums are **not** `java.lang.Enum`. They are classes:

```java
public final class SubscriptionStatus {
  // Constants
  public static final SubscriptionStatus UNKNOWN = ...;
  public static final SubscriptionStatus FREE = ...;
  public static final SubscriptionStatus PREMIUM = ...;

  // Internal kind discriminator
  public enum Kind {
    UNKNOWN,
    FREE_CONST,       // suffix _CONST for constant variants
    PREMIUM_CONST,
    TRIAL_WRAPPER,    // suffix _WRAPPER for wrapper variants
  }

  public Kind kind() { ... }

  // Wrapper factory methods
  public static SubscriptionStatus wrapTrial(Trial trial) { ... }
  // Accessor for wrapper value
  public Trial asTrial() { ... }  // throws if not TRIAL_WRAPPER

  // Visitor pattern (guarantees exhaustive matching at compile time)
  public interface Visitor<T> {
    T onUnknown();
    T onFree();
    T onPremium();
    T onTrial(Trial trial);
  }
  public <T> T accept(Visitor<T> visitor) { ... }

  public static final Serializer<SubscriptionStatus> SERIALIZER = ...;

  public static final class Trial {
    // nested struct for the wrapper
    ...
  }
}
```

Key Java enum specifics:
- `Kind` inner enum has values `{NAME}_CONST` for constant variants and
  `{NAME}_WRAPPER` for wrapper variants.
- Two ways to branch: `switch (status.kind()) { case FREE_CONST: ... }` or the
  `Visitor<T>` interface (which gives compile-time exhaustiveness via `abstract
  methods`).
- `accept(Visitor<T>)` calls the appropriate method.

#### Methods (Java)

```java
// Methods.java
public final class Methods {
  public static final build.skir.service.MethodDescriptor<GetUserRequest, GetUserResponse>
      GET_USER = ...;
  public static final build.skir.service.MethodDescriptor<AddUserRequest, AddUserResponse>
      ADD_USER = ...;
}
```

Usage:

```java
ServiceClient client = new ServiceClient("http://localhost:8080/api");
GetUserResponse response = client.invokeRemoteBlocking(
    Methods.GET_USER, request, headers, timeout);
```

---

### 6.6 Kotlin

#### Files produced

One or a few `.kt` files per module, placed in
`src/main/kotlin/skirout/{module_name}/`.

Common pattern: a single `{module_name}.kt` file contains all types for that
module.

#### Client library

Added as a Gradle/Maven dependency.

#### Struct generation (Kotlin)

```kotlin
package skirout.user

data class User private constructor(
  val name: String,
  val pets: List<Pet>,
  val quote: String,
  val subscriptionStatus: SubscriptionStatus,
  val userId: Int,
  internal val _u: UnrecognizedFields<User>?,
) {
  companion object {
    fun partial(
      name: String = "",
      pets: List<Pet.OrMutable> = emptyList(),
      quote: String = "",
      subscriptionStatus: SubscriptionStatus = SubscriptionStatus.UNKNOWN,
      userId: Int = 0,
    ): User = ...

    val DEFAULT: User = partial()

    val SERIALIZER: build.skir.Serializer<User> = ...
    val TYPE_DESCRIPTOR: build.skir.reflection.StructDescriptor<User, User.Mutable> = ...
  }

  /** Deprecated alias to prevent accidental use; Kotlin data class copy() breaks immutability sealing. */
  @Deprecated("Use partial() or toMutable()", level = DeprecationLevel.ERROR)
  fun copy(...): User = ...

  fun toMutable(): Mutable = Mutable(name, pets.toMutableList(), ...)

  class Mutable(
    var name: String = "",
    var pets: MutableList<Pet_OrMutable> = mutableListOf(),
    var subscriptionStatus: SubscriptionStatus = SubscriptionStatus.UNKNOWN,
    var userId: Int = 0,
  ) {
    val mutablePets: MutableList<Pet_OrMutable>
      get() = if (pets is MutableList) pets as MutableList else mutableListOf(*pets.toTypedArray()).also { pets = it }

    fun toFrozen(): User = User(...)
  }

  typealias OrMutable = User // Kotlin doesn't have union types; uses sealed interface

  class Pet(...) { ... }  // nested struct
}
```

Key Kotlin specifics:
- `data class` with `private constructor` — prevents direct construction.
- `companion object` holds `partial()`, `DEFAULT`, `SERIALIZER`, `TYPE_DESCRIPTOR`.
- `partial()` is the main construction method; all parameters have defaults.
- Kotlin `copy()` from `data class` is **deprecated with ERROR level** to prevent
  accidental use (it wouldn't enforce immutability invariants). Users should use
  `toMutable()` + modify + `toFrozen()`, or use `partial()`.
- Field names: `camelCase` (same as Java/TypeScript).
- Nullability: `T?` for optional fields.
- Lists: `List<T>` for frozen arrays; `MutableList<T>` in `Mutable` class.
- `mutableX` computed property on `Mutable`: returns a `MutableList`, upgrading
  in place if needed.

#### Enum generation (Kotlin)

```kotlin
sealed class SubscriptionStatus {
  object UNKNOWN : SubscriptionStatus()
  object FREE : SubscriptionStatus()
  object PREMIUM : SubscriptionStatus()
  data class trial(val value: Trial) : SubscriptionStatus()

  val kind: Kind get() = when (this) {
    is UNKNOWN -> Kind.UNKNOWN
    is FREE -> Kind.FREE
    is PREMIUM -> Kind.PREMIUM
    is trial -> Kind.TRIAL
  }

  enum class Kind { UNKNOWN, FREE, PREMIUM, TRIAL }

  data class Trial(val startTime: skir.Timestamp) { ... }

  companion object {
    val SERIALIZER: build.skir.Serializer<SubscriptionStatus> = ...
  }
}
```

Kotlin pattern matching:

```kotlin
when (status) {
  SubscriptionStatus.FREE -> "free"
  SubscriptionStatus.PREMIUM -> "premium"
  is SubscriptionStatus.trial -> "trial since ${status.value.startTime}"
  SubscriptionStatus.UNKNOWN -> "unknown"
}
```

#### Methods (Kotlin)

```kotlin
val GetUser: build.skir.service.Method<GetUserRequest, GetUserResponse> = ...
val AddUser: build.skir.service.Method<AddUserRequest, AddUserResponse> = ...
```

---

### 6.7 Dart

#### Files produced

One `.dart` file per module, placed in `lib/skirout/`:
- `lib/skirout/user.dart` for `user.skir`

#### Client library

```yaml
# pubspec.yaml
dependencies:
  skir_client: ^x.y.z
```

Import: `import 'package:skir_client/skir_client.dart';`

#### Struct generation (Dart)

```dart
import 'package:skir_client/skir_client.dart';

/// Deeply immutable.
final class User {
  const User._({
    required this.name,
    required this.pets,
    required this.subscriptionStatus,
    required this.userId,
    required this.internalU_,
  });

  final String name;
  final List<Pet> pets;   // _FrozenList — immutable
  final SubscriptionStatus subscriptionStatus;
  final int userId;               // int for int32 and int64
  final internal__UnrecognizedFields? internalU_;

  static User partial({
    String name = "",
    Iterable<Pet_OrMutable>? pets,
    SubscriptionStatus? subscriptionStatus,
    int userId = 0,
  }) => ...

  static final User DEFAULT = partial();

  static final Serializer<User> serializer = ...;

  User_mutable mutable() => User_mutable(
    name: name,
    pets: List.of(pets),
    subscriptionStatus: subscriptionStatus,
    userId: userId,
  );

  @override
  bool operator ==(Object other) => ...;
  @override
  int get hashCode => ...;

  // Nested type access
  static const pet = _UserPetFactory();  // or similar, for User.Pet constructor
}

final class User_mutable {
  String name;
  List<Pet_OrMutable> pets;    // mutable list
  SubscriptionStatus subscriptionStatus;
  int userId;

  List<Pet_OrMutable> get mutablePets {
    // lazy upgrade: if pets is not a plain List already, copy it
    ...
  }

  User toFrozen() => ...;
}

typedef User_OrMutable = Object;  // union type approximation
```

Key Dart specifics:
- The frozen class is declared `final` (cannot be subclassed).
- Constructor is private (`User._(...)`); creation is via `partial(...)`.
- Fields are `final`.
- Lists are stored as `_FrozenList` (an unmodifiable list subtype).
- Optional fields: `T?` (Dart nullable).
- Integer types: all integers in Dart are `int` (64-bit on most platforms); both
  `int32` and `int64` map to `int`.
- Timestamp: `skir_client` provides a `Timestamp` class.
- Nested types: defined at top level with a name-mangled name (e.g., `User_Pet`,
  `SubscriptionStatus_Trial`) and re-exported via type aliases or static fields
  on the parent.

#### Enum generation (Dart)

Dart uses a **sealed class** hierarchy:

```dart
sealed class SubscriptionStatus {
  const SubscriptionStatus._();

  static const SubscriptionStatus UNKNOWN = _SubscriptionStatus_UNKNOWN._();
  static const SubscriptionStatus FREE    = _SubscriptionStatus_FREE._();
  static const SubscriptionStatus PREMIUM = _SubscriptionStatus_PREMIUM._();

  static SubscriptionStatus wrapTrial(SubscriptionStatus_Trial value) =>
      _SubscriptionStatus_trial._(value);

  SubscriptionStatus_kind get kind;

  static final Serializer<SubscriptionStatus> serializer = ...;
}

enum SubscriptionStatus_kind { UNKNOWN, FREE, PREMIUM, trial }

final class _SubscriptionStatus_FREE extends SubscriptionStatus {
  const _SubscriptionStatus_FREE._() : super._();
  @override SubscriptionStatus_kind get kind => SubscriptionStatus_kind.FREE;
}

final class _SubscriptionStatus_trial extends SubscriptionStatus {
  const _SubscriptionStatus_trial._(this.value) : super._();
  final SubscriptionStatus_Trial value;
  @override SubscriptionStatus_kind get kind => SubscriptionStatus_kind.trial;
}
```

Pattern matching in Dart:

```dart
switch (status) {
  case _ when status.kind == SubscriptionStatus_kind.FREE:
    return "free";
  case _ when status.kind == SubscriptionStatus_kind.trial:
    final s = status as _SubscriptionStatus_trial;
    return "trial since ${s.value.startTime}";
  // ...
}
// Or:
switch (status) {
  case _SubscriptionStatus_FREE(): return "free";
  case _SubscriptionStatus_trial(:final value): return "trial since ${value.startTime}";
  // ...
}
```

#### Keyed arrays (Dart)

```dart
final KeyedIterable<User, int> users;
// usage:
final user = userRegistry.users.findByKey(42);
```

`KeyedIterable<T, K>` is provided by the client library; it wraps a `List<T>` and
builds a lazy hash map on first lookup.

#### Methods (Dart)

```dart
final Method<GetUserRequest, GetUserResponse> getUser =
    Method(number: 12345, name: 'GetUser', ...);
```

---

## 7. Client Library Responsibilities

The client library is the runtime package that the generated code imports. It
must provide:

### 7.1 Core serializer types

```
Serializer<T>
  toJson(value: T) → JsonValue          // dense JSON, parsed value (not string)
  fromJson(json: JsonValue) → T
  toJsonCode(value: T, flavor?: "dense"|"readable") → String
  fromJsonCode(code: String) → T        // auto-detects flavor
  toBytes(value: T) → ByteString
  fromBytes(bytes: ByteString | Buffer) → T
  typeDescriptor: TypeDescriptor<T>
```

### 7.2 Primitive serializers

Accessible via `primitiveSerializer("int32")` etc. (TypeScript) or
`Serializers.int32()` (Java) etc.:

- `bool`, `int32`, `int64`, `hash64`, `float32`, `float64`, `string`, `bytes`,
  `timestamp`

### 7.3 Composite serializers

- `arraySerializer(elementSerializer)` → `Serializer<T[]>`
- `optionalSerializer(valueSerializer)` → `Serializer<T | null>`

### 7.4 Timestamp type

The client library provides a `Timestamp` type (since most languages don't have a
native millisecond-precision timestamp that maps cleanly to the Skir wire format):

- `Timestamp.UNIX_EPOCH` / `Timestamp.EPOCH` — the epoch constant
- `Timestamp.fromUnixMillis(millis)` / `Timestamp.from_unix_millis(millis)` — factory
- `timestamp.unixMillis` / `timestamp.unix_millis` — the integer value
- Arithmetic, comparison, ordering (optional but useful)
- Clamping to the valid Skir range (±100M days)
- Parsing from ISO 8601 strings (for easy constant construction)

### 7.5 ByteString type

Wrapper around a byte buffer that provides:
- `ByteString.of(bytes)` / `ByteString.sliceOf(buffer)` — factory
- `toBuffer()` — raw bytes
- Base64 encoding/decoding

### 7.6 KeyedItems type

A specialized collection returned from keyed-array fields on frozen structs:
- Behaves as a sequence (ordered iteration, indexing).
- `find(key) → T | null` / `findByKey(key) → T | null` — lazy hash-map lookup
  (O(N) on first call, O(1) thereafter).
- `findOrDefault(key) → T` — returns `DEFAULT` if not found.

In Java, the generated code uses `List<T>` with a custom `findByKey(key)` method;
in Python, `KeyedItems[T, K]`; in TypeScript/C++/Dart customized wrapper types.

### 7.7 Base classes for generated records

At a minimum, frozen structs need a base class/interface for plumbing:
- `toFrozen() → T` (no-op)
- `toMutable() → T.Mutable` (shallow copy)
- `serializer` (static)

Enums similarly need:
- `union.kind` / `union.value` pattern (TypeScript/Python)
- Or `kind()` method (C++/Java/Kotlin/Dart)

### 7.8 Service (server-side)

```
Service<RequestMeta>
  addMethod(methodDescriptor, handler: (req, meta) → Promise<Response>)
  handleRequest(bodyString, metadata) → Promise<RawResponse>
  options: ServiceOptions { keep_unrecognized_values, can_send_unknown_error_message, ... }

RawResponse
  statusCode: int
  contentType: string
  data: string | bytes
```

HTTP glue (e.g., `installServiceOnExpressApp`) is separate from the core service
logic.

### 7.9 ServiceClient (client-side)

```
ServiceClient(baseUrl: string)
  invokeRemote(method, request, httpMethod?: "POST"|"GET") → Promise<Response>
  invokeRemoteBlocking(method, request, headers, timeout) → Response  // Java
  invoke_remote(method, request, headers?) → Response  // Python sync
```

Transports request as: `{method_name}:{number}:dense:{dense_json}` in the body
(POST) or URL query string (GET).

### 7.10 Reflection types

```
TypeDescriptor — describes any Skir type (primitive, array, optional, record)
StructDescriptor — lists fields (name, number, type descriptor, doc)
EnumDescriptor — lists variants (name, number, type descriptor if wrapper)
```

Used for building generic utilities (serializers, validators, transformers) that
work on any Skir type without needing to know the specific type at compile time.

### 7.11 ReflectiveTransformer / ReflectiveTypeVisitor (Java/Dart)

A visitor interface for transforming any Skir value:

```java
// Java
public interface ReflectiveTransformer {
  <T> T transform(T input, TypeDescriptor.Reflective<T> descriptor);
}

public abstract class ReflectiveTypeVisitor<T> {
  void visitStruct(StructDescriptor.Reflective<T, Mutable> descriptor);
  void visitEnum(EnumDescriptor.Reflective<T> descriptor);
  void visitString(TypeEquivalence<T, String> equivalence);
  // ... visitArray, visitOptional, visitPrimitive, etc.
}
```

The Dart equivalent is `ReflectiveTransformer` and `ReflectiveTypeVisitor` in
`skir_client.dart`.

---

## 8. Edge Cases and Tests

The golden-test suite in `skir/golden-tests/` (and reproduced in each generator's
`e2e-test/`) defines the authoritative behavior for serialization. The suite
covers:

### 8.1 Default struct encoding

An all-default struct serializes as `[]` (empty array). A struct with only the
first field non-default serializes as `[field0_value]`.

### 8.2 Removed fields

A struct with `removed;` at position N encodes its subsequent fields shifted up
by N. When deserializing a value with a `0` at position N, that zero is
understood as the removed placeholder and the field at position N is treated as
absent.

### 8.3 Enum edge cases

- UNKNOWN variant: by default (when not keeping unrecognized values) the UNKNOWN
  variant is treated as the all-default sentinel; during serialization it writes
  `0` (or the unrecognized bytes if present).
- Unrecognized constant variant: a constant variant number not in the schema is
  ignored (or preserved as unrecognized if `keep_unrecognized_values`).
- Unrecognized wrapper variant: the entire `[number, value]` array is stored
  verbatim if `keep_unrecognized_values`, otherwise dropped.

### 8.4 NaN, Infinity, -Infinity

These are legal float32/float64 values. Dense JSON: serialized as strings
`"NaN"`, `"Infinity"`, `"-Infinity"`. Readable JSON: same. Binary: IEEE 754
representation.

### 8.5 Large arrays and strings

The binary format uses `0xfa` (length prefix) for arrays longer than 3 elements.
The length is encoded using the variable-length integer encoding (same as int32).
Similarly, non-empty strings use the variable-length encoding for their byte
length.

### 8.6 Recursive structs

When a struct field refers back to its own type (directly or indirectly), the
generated code wraps it in a heap-allocated indirection:
- C++: `skir::rec<T>` — a smart-pointer-like wrapper with lazy allocation.
- Dart: a private sentinel field `_rec_fieldName` holding `T?`, with a getter that
  returns it or the default.
- Python/TypeScript/Java/Kotlin: the language's own heap allocation (all objects
  are heap-allocated anyway) handles this transparently.

### 8.7 Keyed arrays with enum keys

`[Item|weekday.kind]` uses `Weekday_kind` (the kind enum) as the key type in the
generated code. The lookup function takes a `Weekday_kind` value.

### 8.8 int32 vs int64 parsability

When deserializing JSON integers, parsers should accept:
- JSON numbers for both `int32` and `int64`/`hash64` fields.
- JSON strings (e.g., `"123"`) for `int64`/`hash64` fields (and preferably for
  `int32` too, for cross-language compatibility since some implementations like
  C++ always write int64 as strings).

### 8.9 Optional fields vs struct fields

- `T?` (optional): `0` in dense JSON decodes as the inner type's default (not null).
- A struct field (non-optional): `0` or `[]` both decode as the default struct.

### 8.10 Unrecognized fields round-trip

When `keep_unrecognized_values = true`:
1. Read a value with extra fields (from a newer schema).
2. Write it back.
3. The extra fields must be present in the output.
4. This applies to both dense JSON and binary format; the stored format (JSON vs
   binary) must be preserved during the round-trip (i.e., unrecognized JSON
   fields are re-emitted as JSON, not re-encoded as binary).

---

## 9. Skir Schema vs Code naming conventions

| Schema element | TypeScript | Python | C++ | Java | Kotlin | Dart |
|---|---|---|---|---|---|---|
| Struct name `FooBar` | `FooBar` class | `FooBar` class | `FooBar` struct (in `skirout_{module}` ns) | `FooBar` class | `FooBar` data class | `FooBar` final class |
| Nested struct `Outer.Inner` | `Outer_Inner` class + `Outer.Inner` type alias | `Outer.Inner` inner class | `Outer_Inner` struct | `Outer.Inner` inner static class | `Outer.Inner` nested class | `Outer_Inner` top-level final class |
| Field `snake_case_name` | `camelCaseName` property | `snake_case_name` property | `snake_case_name` member | `camelCaseName()` method | `camelCaseName` property | `camelCaseName` field |
| Constant variant `FREE` | `SubscriptionStatus.FREE` | `SubscriptionStatus.FREE` | `skirout::kFree` / `SubscriptionStatus::kFree` | `SubscriptionStatus.FREE` | `SubscriptionStatus.FREE` | `SubscriptionStatus.FREE` |
| Wrapper variant `trial` | `{ kind: "trial", value: ... }` | `wrap_trial(...)` / `create_trial(...)` | `SubscriptionStatus::wrap_trial(...)` / `skirout::wrap_trial(...)` | `SubscriptionStatus.wrapTrial(...)` | `SubscriptionStatus.trial(value)` | `SubscriptionStatus.wrapTrial(...)` |
| Module constant `TARZAN` | `export const TARZAN` | module-level `TARZAN` | `skirout_user::k_tarzan()` function | `Constants.TARZAN` | top-level `val TARZAN` | top-level `const TARZAN` |
| Method `GetUser` | `export const GetUser` | module-level `GetUser` | `skirout_methods::GetUser` struct | `Methods.GET_USER` | top-level `val GetUser` | top-level `getUser` val |

---

## 10. Generator Input Format

Each code generator receives the parsed schema as a structured tree (the Skir
compiler emits a JSON/stream representation). Key fields generators rely on:

- Module name (derived from file path).
- List of records (struct/enum), each with:
  - Name, stable ID (if set), doc comment.
  - For structs: list of fields (name, number, type, doc, removed numbers list).
  - For enums: list of constant variants and wrapper variants (name, number,
    type-of-value, doc, removed numbers list).
  - Parent record reference (for nesting).
- List of methods (name, number, request type ref, response type ref, doc).
- List of constants (name, type ref, rendered dense JSON value).
- List of imports (module and symbols imported).

The generator is responsible for:
1. Rendering each record into target-language syntax.
2. Handling naming conflicts (e.g., a field named `default` in a language that has
   `default` as a keyword).
3. Generating the serializer registration / module initialization call.
4. Propagating doc comments.
5. Generating module-level imports.

---

## 11. Naming Edge Cases

### 11.1 Field names clashing with language keywords

If a schema field is named `class`, `default`, `type`, `import`, etc. in a
language that reserves those words, the generator must escape the name. Observed
patterns:
- Kotlin: field named `class` → renamed to `class_` in the data class (suffix
  underscore). The serialization name remains `class`.
- C++: no special handling needed since fields are simple struct members.
- Java: similarly use a suffix (`class_`, `type_`, etc.) if needed.

### 11.2 Name collisions between nested types and ancestor types

If nested type `Name.Name` creates a generated type named `Name_Name` that
clashes with something else, unique suffixes are applied. The e2e tests cover
cases like `Name`, `Name.Name1`, `Name.Name2`, `Name.Name_Name` etc.

### 11.3 Enum variant named `default`

Not special-cased; the generated code uses the exact name in the variant's string
representation and the language-appropriate casing elsewhere.

---

## 12. Large-Value Handling

The binary format includes special handling for large arrays and strings that
exceed the single-byte length range. The variable-length integer encoding
(described in §3.3) handles lengths up to 2^31-1. Tests confirm:

- An array of 300 `bool` fields serializes with the correct 5-byte prefix:
  `{0xfa, length_bytes...}`.
- A string of N characters serializes with a length prefix using variable-length encoding.
- Very large arrays (>3 items) use the `0xfa` marker; 1-3 items use `0xf7/0xf8/0xf9`.

---

## 13. Summary Checklist for a New Generator

When building a code generator for language X:

- [ ] Map all 9 primitive types to X-native types.
- [ ] Generate frozen struct class/record with:
  - [ ] Typed property accessors (read-only).
  - [ ] Full-construction factory (all fields required).
  - [ ] Partial-/default-construction factory.
  - [ ] Copy-with-modification (replace/toBuilder/copy pattern).
  - [ ] `toMutable()` / `mutable()` method.
  - [ ] `toFrozen()` no-op method.
  - [ ] `DEFAULT` constant.
  - [ ] `serializer` constant/static.
  - [ ] `==` and hash code.
  - [ ] `toString` (returns readable JSON).
  - [ ] Nested type re-exports/aliases.
- [ ] Generate mutable struct class/record with:
  - [ ] Writable properties.
  - [ ] `mutableX` lazy-upgrade getter for nested struct/array fields.
  - [ ] `toFrozen()` that deep-freezes.
- [ ] Generate enum class/sealed class with:
  - [ ] `UNKNOWN` constant.
  - [ ] One constant per constant variant.
  - [ ] One wrapper factory per wrapper variant.
  - [ ] Kind discriminator (`kind` / `kind()` / `union.kind`).
  - [ ] Value accessor for wrapper variants.
  - [ ] Pattern-matching support (switch/when/match/visitor).
  - [ ] `serializer`.
- [ ] Generate keyed-array with `find(key) → T | null` method on frozen structs.
- [ ] Generate method descriptors with `{name, number, requestSerializer, responseSerializer}`.
- [ ] Generate constants as lazily-initialized deserialized objects.
- [ ] Generate module initialization code linking all classes to their serializers.
- [ ] Handle unrecognized fields (store in `_unrecognized`/`_u` internal field).
- [ ] Handle recursive types with heap indirection.
- [ ] Propagate doc comments to generated code.

## 14. Summary Checklist for a New Client Library

When building a client library for language X:

- [ ] Implement `Serializer<T>` with `toJson/fromJson/toJsonCode/fromJsonCode/toBytes/fromBytes/typeDescriptor`.
- [ ] Implement all 9 primitive serializers with correct wire format (§3.1–3.3).
- [ ] Implement `arraySerializer` and `optionalSerializer`.
- [ ] Implement `Timestamp` type with epoch constant, from/to unix millis, arithmetic.
- [ ] Implement `ByteString` type with base64 encode/decode.
- [ ] Implement `KeyedItems<T,K>` with lazy hash map and `find` / `findOrDefault`.
- [ ] Implement `StructSerializer` builder that registers fields (name, number, type serializer, getter, setter).
- [ ] Implement `EnumSerializer` builder that registers variants (name, number, type serializer if wrapper).
- [ ] Implement unrecognized-field storage and round-trip preservation.
- [ ] Implement type descriptor JSON serialization/deserialization.
- [ ] Implement `Service` / `ServiceAsync` with `addMethod` and `handleRequest` (returns `RawResponse`).
- [ ] Implement `ServiceClient` with `invokeRemote` (encodes request, sends HTTP, decodes response).
- [ ] Implement dense JSON deserialization that:
  - [ ] Treats `0` as default for any non-optional type.
  - [ ] Accepts both `[...]` (dense) and `{...}` (readable) objects.
  - [ ] Accepts both JSON numbers and JSON strings for integer types.
  - [ ] Preserves unrecognized fields if `keep_unrecognized_values` is set.
- [ ] Implement binary serialization/deserialization with little-endian byte order and variable-length encoding.
- [ ] Handle NaN/Infinity/-Infinity for floats.
- [ ] Implement reflection types (`TypeDescriptor`, `StructDescriptor`, `EnumDescriptor`).
- [ ] (Optional) Implement `ReflectiveTransformer` / `ReflectiveTypeVisitor` pattern.
