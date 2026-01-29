# Skir Documentation

## Getting started: setup and workflow

### Prerequisites

The Skir compiler requires [Node.js](https://nodejs.org/en/download) to be installed.

### Setting up a project

#### Initialize a project

From your project directory, run:
```bash
npx skir init
```

This command creates:
-   `skir.yml`: the Skir configuration file
-   `skir-src/hello_world.skir`: an example `.skir` file

#### Configure code generation

The `skir.yml` file controls how Skir generates code for your project. Here's an example:

```yml
# skir.yml

generators:
  - mod: skir-cc-gen
    outDir: ./app/src/skirout
    config:
      writeGoogleTestHeaders: true
  - mod: skir-typescript-gen
    outDir: ./frontend/skirout
    config: {}
```

All paths are relative to the directory containing `skir.yml` (the root directory).

Every generator entry has the following properties:

-    `mod`: Identifies the code generator to run (e.g., `skir-python-gen` for Python).
-    `outDir`: The output directory for generated source code (e.g., `./src/skirout`). The directory **must** be named `skirout`. If you specify an array of strings, the generator will write to multiple output directories, which is useful when you have multiple sub-projects in the same language.
-    `config`: Generator-specific configuration. Use `{}` for default settings.

#### Output directory location

Typically, you should place the skirout directory at the root of your sub-project's source tree. However, placement varies by ecosystem to ensure idiomatic results:
-   TypeScript: It's often more convenient to place `skirout` adjacent to the `src` directory.
-   Java / Kotlin / Python: Place the directory inside your top-level package (e.g., `src/main/java/com/myproject/skirout`). This ensures generated package names (like `com.myproject.skirout.*`) follow standard naming conventions.

Multiple generators can write to the same output directory, which means this directory will contain source files in different languages.

> [!WARNING]
> Do not manually edit any of the files inside a `skirout` directory. This directory is managed by Skir. Any manual change will be overwritten during the next generation.

### Core workflow

Run Skir code generation before compiling your language-specific source code.

```shell
npx skir gen
```

This command transpiles your `.skir` files into the target languages specified in your configuration. This creates or updates your `skirout` directories containing the generated source code.

For a more seamless experience, consider using watch mode:

```shell
npx skir gen --watch
```

The compiler will monitor your source directory and automatically regenerate code whenever you modify a `.skir` file.

> [!TIP]
> If your project is a Node project, add add `skir gen` to your `package.json` scripts. Using the `prebuild` hook is recommended so that code is regenerated automatically before every build.
> ```json
> {
>   "scripts": {
>     "prebuild": "skir gen",
>     "build": "tsc" 
>   }
> }
> ```
> *For a full implementation, see this [example project](https://github.com/gepheum/skir-typescript-example/blob/main/package.json).*

### Formatting `.skir` files

Use `npx skir format` to format all `.skir` files in your project.

### Continuous integration (GitHub)

We recommend adding `skirout` to `.gitignore` and running Skir code generation in your GitHub workflow. GitHub's hosted runners (Ubuntu, Windows, and macOS) come with Node.js and `npx` pre-installed, so you only need to add one step:

```yml
      - name: Run Skir codegen
        run: npx skir gen
```

If you have a formatting check step, it may fail on Skir-generated code. You can either run the formatting check before Skir codegen, or configure your formatter to skip `skirout` directories.

Consider adding these optional steps for stricter validation:

```yml
      - name: Run Skir format checker
        run: npx skir format --ci

      - name: Ensure Skir snapshot up-to-date
        run: npx skir snapshot --ci
```

The first step ensures `.skir` files are properly formatted. The second step verifies that you ran `npx skir snapshot` before committing. See [Schema evolution & compatibility](#schema-evolution--compatibility) for more information about the snapshot command.

### IDE support

The official VS Code [extension](https://marketplace.visualstudio.com/items?itemName=TylerFibonacci.skir-language) for Skir provides syntax highlighting, auto-formatting, validation, jump-to-definition, and other language features.


## Language reference

### Records

There are two types of records: structs and enums.

#### Structs

Use the keyword `struct` to define a struct, which is a collection of fields of different types.

The fields of a struct have a name, but during serialization they are actually identified by a number, which can either be set explicitly:

```d
struct Point {
  x: int32 = 0;
  y: int32 = 1;
  label: string = 2;
}
```

or implicitly:

```d
struct Point {
  x: int32;  // implicitly set to 0
  y: int32;  // implicitly set to 1
  label: string;  // implicitly set to 2
}
```

If you're not explicitly specifying the field numbers, you must be careful not to change the order of the fields or else you won't be able to deserialize old values.

```d
// BAD: you can't reorder the fields and keep implicit numbering
// struct Point {
//  label: string;
//   x: int32;
//   y: int32;
// }

// GOOD
struct Point {
  label: string = 2;

  // Fine to rename fields
  x_coordinate: int32 = 0;
  y_coordinate: int32 = 1;

  // Fine to add new fields
  color: Color = 3;
}
```

#### Enums

Enums in Skir are similar to enums in Rust. An enum value is one of several possible variants, and each variant can optionally have data associated with it.

```d
// Indicates whether an operation succeeded or failed.
enum OperationStatus {
  SUCCESS;  // a constant variant
  error: string;  // a wrapper variant
}
```

In this example, an `OperationStatus` is one of these 3 things:

*   the `SUCCESS` constant
*   an `error` with a string value
*   `UNKNOWN`: a special implicit variant common to all enums

If you need a variant to hold multiple values, wrap them inside a struct:

```d
struct MoveAction {
  x: int32;
  y: int32;
}

enum BoardGameTurn {
  PASS;
  move: MoveAction;
}
```

Like the fields of a struct, the variants of an enum have a number, and the numbering can be explicit or implicit.

```d
enum ExplicitNumbering {
  // The numbers don't need to be consecutive.
  FOO = 10;
  bar: string = 2;
}

enum ImplicitNumbering {
  // Implicit numbering is 1-based.
  // 0 is reserved for the special UNKNOWN variant.

  FOO;  // = 1
  bar: string;  // = 2
}
```

The variant numbers are used for identifying the variants in the serialization format (not the variant names). You must be careful not to change the number of a variant, or you won't be able to deserialize old values. For example, if you're using implicit numbering, you must not reorder the variants.

It is always fine to rename an enum, rename the variants of an enum, or add new variants to an enum.

#### Nesting records

You can define a record (struct or enum) within the definition of another record. This is simply for namespacing, and it can help make your `.skir` files more organized.

```d
enum Status {
  OK;

  struct Error {
    message: string;
  }
  error: Error;
}

struct Foo {
  // Note the dot notation to refer to the nested record.
  error: Status.Error;
}
```

#### Inline records

For improved readability and conciseness, Skir allows you to define records (structs or enums) directly within a field's type definition. This **inline** syntax is a shorthand for explicitly nesting a record definition and then referencing it as a type.

When you use an inline record, the Skir compiler automatically infers the name of the record by converting the `snake_case` field name into `PascalCase`.

For example, imagine you are defining a `Notification` system where each message can have different types of payloads.

```d
// Not using inline records

struct Notification {
  metadata: Metadata;
  struct Metadata {
    sent_at: timestamp;
    sender_id: string;
  }

  payload: Payload;
  enum Payload {
    APP_LAUNCH;

    message: Message;
    struct Message {
      body: string;
      title: string;
    }
  }
}
```

Using inline records, the same structure can be defined more concisely. The compiler will infer that the type for `metadata` is `Metadata` and the type for `payload` is `Payload`.

```d
// Using inline records

struct Notification {
  metadata: struct {
    sent_at: timestamp;
    sender_id: string;
  }

  payload: enum {
    APP_LAUNCH;
    message: struct {
      body: string;
      title: string;
    }
  }
}
```

These two methods of definition are strictly equivalent. The generated code will be identical regardless of whether the record was defined explicitly or inline.

#### Removed numbers

When removing a field from a struct or a variant from an enum, you must mark the removed number in the record definition using the `removed` keyword. The syntax is different whether you're using explicit or implicit numbering:

```d
struct ExplicitNumbering {
  a: string = 0;
  b: string = 1;
  f: string = 5;
  removed 2..4, 6;  // 2..4 is same as 2, 3, 4
}

struct ImplicitNumbering {
  a: string;
  b: string:
  removed;
  removed;
  removed;
  f: string;
  removed;
}
```

#### Stable identifiers

You can assign a numeric stable identifier to a struct or an enum by specifying it in parentheses after the record name:

```d
struct Point(23456) { ... }
```

This identifier is used by the `npx skir snapshot` command to track record identity across renames and detect breaking changes. For more information, see the [compatibility guide](#schema-evolution--compatibility).

No two types in your Skir project can have the same stable identifier.

> [!TIP]
> You can use `?` as a placeholder for the identifier and run `npx skir format`. It will replace the question mark with a generated random number. This replacement happens automatically on save if you are using the [VSCode extension](https://marketplace.visualstudio.com/items?itemName=TylerFibonacci.skir-language).

#### Recursive records

Records can be recursive, meaning a record can contain a field of its own type, either directly or indirectly. This feature is essential for defining recursive data structures such as trees.

```d
struct DecisionNode {
  question: string;
  yes: DecisionTree;
  no: DecisionTree;
}

enum DecisionTree {
  result: string;
  node: DecisionNode;
}
```

To safeguard against infinite recursion, the generated code in all supported languages has compile-time constraints to prevent an instance of a recursive type from containing itself.

### Data types

#### Primitive types

*   `bool`: true or false
*   `int32`: a signed 32-bit integer
*   `int64`: a signed 64-bit integer
*   `hash64`: an unsigned 64-bit integer; prefer using this for hash codes and `int64` for numbers which represent an actual *count*
*   `float32`: a 32-bit floating point number; can be one of `NaN`, `Infinity` or `-Infinity`
*   `float64`: a 64-bit floating point number; can be one of `NaN`, `Infinity` or `-Infinity`
*   `string`: a Unicode string
*   `bytes`: a sequence of bytes
*   `timestamp`: a specific instant in time represented as an integral number of milliseconds since the Unix epoch, from 100M days before the Unix epoch to 100M days after the Unix epoch

#### Array type

Wrap the item type inside square brackets to represent an array of items, e.g. `[string]` or `[User]`.

##### Keyed arrays

If the items are structs and one of the struct fields can be used to identify every item in the array, you can add the field name next to a pipe character: `[Item|key_field]`.

Example:
```d
struct User {
  id: int32;
  name: string;
}

struct UserRegistry {
  users: [User|id];
}
```

Language plugins will generate methods allowing you to perform key lookups in the array using a hash table. For example, in Python:

```python
user = user_registry.users.find(user_id)
if user:
    do_something(user)
```

If the item key is nested within another struct, you can chain the field names like so: `[Item|a.b.c]`.

The key type must be a primitive type of an enum type. If it's an enum type, add `.kind` at the end of the key chain:

```d
enum Weekday {
  MONDAY;
  TUESDAY;
  WEDNESDAY;
  THURSDAY;
  FRIDAY;
  SATURDAY;
  SUNDAY;
}

struct WeekdayWorkStatus {
  weekday: Weekday;
  working: bool;
}

struct Employee {
  weekly_schedule: [WeekdayWorkStatus|weekday.kind];
}
```

#### Optional type

Add a question mark at the end of a non-optional type to make it optional. An `other_type?` value is either an `other_type` or null.

### Constants

You can define constants of any type with the `const` keyword. The syntax for representing the value is similar to JSON, with the following differences:

*   object keys must not be quoted
*   trailing commas are allowed and even encouraged
*   strings can be single-quoted or double-quoted
*   strings can span multiple lines by escaping new line characters

```d
const PI: float64 = 3.14159;

const LARGE_CIRCLE: Circle = {
  center: {
    x: 100,
    y: 100,
  },
  radius: 100,
  color: {
    r: 255,
    g: 0,
    b: 255,
    label: "fuschia",
  },
};

const MULTILINE_STRING: string = 'Hello\
world\
!';

const SUPPORTED_LOCALES: [string] = [
  "en-GB",
  "en-US",
  "es-MX",
];

// Use strings for enum constants.
const REST_DAY: Weekday = "SUNDAY";

// Use { kind: ..., value: ... } for enum variants holding a value.
const NOT_IMPLEMENTED_ERROR: OperationStatus = {
  kind: "error",
  value: "Not implemented",
};
```

All the fields of a struct must be specified, unless you use `{| ... |}` instead of `{ ... }`, in which case missing fields are set to their default values.

### Methods (RPCs)

The `method` keyword allows you to define the signature of a remote method.

```d
struct GetUserProfileRequest {
  user_id: int32;
}

struct GetUserProfileResponse {
  profile: UserProfile?;
}

method GetUserProfile(GetUserProfileRequest): GetUserProfileResponse = 12345;
```

The request and response can have any type.

#### Stable identifiers

Every method must have a unique integer identifier (e.g. `= 12345`) used for RPC routing. This identifier decouples the method's identity from its name, allowing safe renaming and refactoring without breaking compatibility with older clients.

No two methods in your Skir project can have the same stable identifier.

> [!TIP]
> You can use `?` as a placeholder for the identifier and run `npx skir format`. It will replace the question mark with a generated random number. This replacement happens automatically on save if you are using the [VSCode extension](https://marketplace.visualstudio.com/items?itemName=TylerFibonacci.skir-language).

#### Inline request/response records

Just as you can define structs and enums inline for fields, Skir supports inline record definitions for RPC methods. This allows you to define the request and response structures directly within the method signature.

When records are defined inline within a method, the Skir compiler automatically generates the record names by appending `Request` to the method name for the input and `Response` for the output.

This syntax allows you to define the same method as above more concisely:

```d
// Using inline records

method GetUserProfile(struct {
  user_id: int32;
}): struct {
  profile: UserProfile?;
} = 12345;
````

### Imports

The `import` statement allows you to import types from another module. You can either specify the names to import, or import the whole module with an alias using the `as` keyword.

```d
import Point, Circle from "geometry/geometry.skir";
import * as color from "color.skir";

struct Rectangle {
  top_left: Point;
  bottom_right: Point;
}

struct Disk {
  circle: Circle;
  fill_color: color.Color;  // the type is defined in the "color.skir" module
}
```

The path is always relative to the root of the Skir source directory.

### Doc comments

Doc comments are designated by three forward slashes (`///`) and are used to provide high-level documentation for records, fields, variants, methods and constants. Unlike regular comments (`//` or `/*`), which are ignored by the compiler, doc comments are processed as part of your schema definition.

#### Referencing symbols

Doc comments can contain references to other symbols within your schema by enclosing them in square brackets. If a symbol referenced in square brackets is missing or misspelled, the Skir compiler will trigger a compilation error. This ensures that your documentation never becomes *stale* or refers to fields that no longer exist.

```d
struct Account {
  /// Same as [User.email]
  email: string;
  /// True if the [email] has been confirmed via a verification link.
  is_verified: bool;
  created_at: timestamp;
}
```

#### Integration with code generators

One of the primary advantages of doc comments is that they are copied directly into the generated code. Developers using IDEs like VSCode or IntelliJ will see your documentation in hover information, code completion, and inlay hints.

#### RPC visibility and security

When documenting types used as a request or response for an RPC method, be aware that these comments may be visible to any user or client with access to that interface.

For this reason, it is critical **not** to include business-confidential information, internal server paths, or sensitive security logic in doc comments for types that will be exposed via public-facing services.


## Serialization

### Serialization formats

When serializing a data structure, you can chose one of 3 formats.

#### JSON, dense flavor

This is the serialization format you should chose in most cases.

Structs are serialized as JSON arrays, where the field numbers in the index definition match the indexes in the array. Enum constants are serialized as numbers.

```d
struct User {
  user_id: int32;
  removed;
  name: string;
  rest_day: Weekday;
  pets: [Pet];
  nickname: string;
}

const JOHN_DOE: User = {
  user_id: 400,
  name: "John Doe",
  rest_day: "SUNDAY",
  pets: [
    { name: "Fluffy" },
    { name: "Fido" },
  ],
  nickname: "",
}
```

The dense JSON representation of `JOHN_DOE` is:

```json
[400,0,"John Doe",7,[["Fluffy"],["Fido"]]]
```

A couple observations:

*   Removed fields are replaced with zeros
*   Trailing fields with default values (`nickname` in this example) are omitted

This format is not very readable, but it's compact and it allows you to rename fields in your struct definition without breaking backward compatibility. 

#### JSON, readable flavor

Structs are serialized as JSON objects, and enum constants are serialized as strings.

The readable JSON representation of `JOHN_DOE` is:

```json
{
  "user_id": 400,
  "name": "Johm Doe",
  "rest_day": "SUNDAY",
  "pets": [
    { "name": "Fluffy" },
    { "name": "Fido" }
  ]
}
```

This format is more verbose and readable, but it should **not** be used if you need persistence, because Skir allows fields to be renamed in record definitions. In other words, never store a readable JSON on disk or in a database.

Note that when Skir *deserializes* JSON, it knows how to handle both dense and readable flavor. It's only when *serializing* JSON that a flavor must be specified.

#### Binary format

This format is a bit more compact than JSON, and serialization/deserialization can be faster in languages like C++. Only prefer this format over JSON when the small performance gain is likely to matter, which should be rare.

### Implementation details

This section describes precisely how each data type is serialized to each of the 3 formats. This information is intended for advanced users who want to understand the inner workings of Skir, or for developers who want to implement a Skir generator for a new programming language.

#### Handling of zeros

Since the dense JSON and binary format use zeros to represent `removed` fields, in order to preserve forward compatibility, zero is a valid input for any type even non-numerical types. With the exception of the optional type, all types will decode "zero" as the default value for the type (e.g. an empty array). The optional type will decode zero as the default value of the underlying type.

#### Primitives

##### Bool

*   **JSON (Readable)**: `true` or `false`.
*   **JSON (Dense)**: `1` for true, `0` for false.
*   **Binary**: A single byte: `1` for true, `0` for false.

##### Int32

*   **JSON**: A JSON number.
*   **Binary**: Variable-length encoding.
    *   **Positive numbers**:
        *   `0` to `231`: Encoded as a single byte with that value.
        *   `232` to `65535`: Encoded as byte `232` followed by a little-endian `uint16`.
        *   `65536` and above: Encoded as byte `233` followed by a little-endian `uint32`.
    *   **Negative numbers**:
        *   `-256` to `-1`: Encoded as byte `235` followed by a single byte representing `value + 256`.
        *   `-65536` to `-257`: Encoded as byte `236` followed by a little-endian `uint16` representing `value + 65536`.
        *   `-65537` and below: Encoded as byte `237` followed by a little-endian `int32`.

##### Int64

*   **JSON**:
    *   If the value is within the safe integer range for JavaScript (±9,007,199,254,740,991), it is serialized as a JSON number.
    *   Otherwise, it is serialized as a string.
*   **Binary**:
    *   `0`: Encoded as a single byte `0`.
    *   If the value fits in an `int32`, it uses the `int32` encoding described above.
    *   Otherwise: Encoded as byte `238` followed by a little-endian `int64`.

##### Hash64

*   **JSON**: Same rule as `int64` (number if safe, string otherwise).
*   **Binary**:
    *   `0` to `231`: Encoded as a single byte with that value.
    *   `232` to `4,294,967,295`: Uses the `int32` positive encoding (byte `232` + `uint16` or byte `233` + `uint32`).
    *   `4,294,967,296` and above: Encoded as byte `234` followed by a little-endian `uint64`.

##### Float32 and Float64

*   **JSON**:
    *   Finite numbers are serialized as JSON numbers.
    *   `NaN`, `Infinity`, and `-Infinity` are serialized as strings: `"NaN"`, `"Infinity"`, `"-Infinity"`.
*   **Binary**:
    *   `0`: Encoded as a single byte `0`.
    *   **Float32**: Encoded as byte `240` followed by a little-endian `float32`.
    *   **Float64**: Encoded as byte `241` followed by a little-endian `float64`.

##### Timestamp

*   **JSON (Readable)**: An object with two fields:
    *   `unix_millis`: The number of milliseconds since the Unix epoch.
    *   `formatted`: An ISO 8601 string representation. Note that when deserializing, only the `unix_millis` field is read.
*   **JSON (Dense)**: A JSON number representing the milliseconds since the Unix epoch.
*   **Binary**:
    *   `0` (Epoch): Encoded as a single byte `0`.
    *   Otherwise: Encoded as byte `239` followed by a little-endian `int64` (milliseconds).

##### String

*   **JSON**: A JSON string.
*   **Binary**:
    *   Empty string: Encoded as byte `242`.
    *   Non-empty: Encoded as byte `243`, followed by the length of the UTF-8 sequence (encoded using the positive `int32` rules: byte, `232`+u16, or `233`+u32), followed by the UTF-8 bytes.

##### Bytes

*   **JSON (Readable)**: The string "hex:" followed by the hexadecimal string.
*   **JSON (Dense)**: A Base64 string.
*   **Binary**:
    *   Empty: Encoded as byte `244`.
    *   Non-empty: Encoded as byte `245`, followed by the length (encoded using `int32` rules), followed by the raw bytes.

#### Complex Types

##### Optional

*   **JSON**: `null` if the value is missing, otherwise the serialized value.
*   **Binary**:
    *   `null`: Encoded as byte `255`.
    *   Value: The serialized value directly.

##### Array

*   **JSON**: A JSON array.
*   **Binary**:
    *   Length `0` to `3`: Encoded as byte `246 + length` (i.e., `246`, `247`, `248`, `249`).
    *   Length `4` and above: Encoded as byte `250`, followed by the length (encoded using `int32` rules).
    *   The items follow immediately after the length marker.

##### Struct

*   **JSON (Readable)**: A JSON object containing field names and values. Default values are omitted.
*   **JSON (Dense)**: A JSON array.
    *   The array index corresponds to the field number.
    *   Removed fields are represented as `0`.
    *   Trailing fields that have default values are omitted to save space.
*   **Binary**:
    *   Encoded similarly to an array.
    *   The "length" represents the number of slots needed to store all fields, after removing trailing fields that have default values.
    *   Length encoding uses the same `246`-`250` markers as arrays.
    *   Fields are written in order. Removed fields are written as byte `0`.

##### Enum

*   **JSON (Readable)**:
    *   **Constant variant**: The name of the variant (string), e.g. `"MONDAY"` or `"UNKNOWN"`.
    *   **Wrapper variant**: An object `{ "kind": "variant_name", "value": ... }`.
*   **JSON (Dense)**:
    *   **Constant variant**: The variant number (integer).
    *   **Wrapper variant**: An array `[variant_number, value]`.
*   **Binary**:
    *   **Unknown**: Encoded as byte `0`.
    *   **Constant variant**: Encoded using the `int32` positive number rules (byte, `232`+u16, etc.).
    *   **Wrapper variant**:
        *   Variant number `1` to `4`: Encoded as byte `250 + number` (i.e., `251`, `252`, `253`, `254`).
        *   Variant number `5` and above: Encoded as byte `248`, followed by the variant number (encoded using `int32` rules).
        *   The value follows immediately.



## Schema evolution & compatibility

Skir is designed for long-term data persistence and distributed systems. It ensures that your application can evolve its data structures while maintaining compatibility with older data (backward compatibility) and older clients (forward compatibility).

### Core concepts

*   **Backward compatibility**: New code can read old data. This is essential for reading records stored in a database created with an older schema.
*   **Forward compatibility**: Old code can read new data. This is critical in distributed systems where different services or clients may be running different versions of your application.

### Safe schema changes

The following changes are safe and preserve both backward and forward compatibility:

#### 1. Adding fields to a struct
New code reading old data will use default values for missing fields:
*   **Numbers**: `0`
*   **Booleans**: `false`
*   **Strings/Bytes**: Empty string/bytes
*   **Arrays**: Empty array `[]`
*   **Structs**: A struct with all fields at their default values
*   **Enums**: The implicit `UNKNOWN` variant
*   **Optional types**: `null`

#### 2. Adding variants to an enum
Old code encountering a new variant will treat it as the implicit `UNKNOWN` variant.

#### 3. Renaming types, fields, and variants
Skir uses numeric identifiers (field numbers) in its binary and compact JSON formats, not names. Therefore, renaming any element is safe.

> [!NOTE]
> Names *are* used in the human-readable JSON format. This format is for debugging only and should not be used for storage or inter-service communication.

#### 4. Removing fields or variants
You must mark the field or variant number as `removed` to prevent accidental reuse.

#### 5. Compatible type changes
You can change a type if the new type is backward-compatible with the old one:
*   `bool` → `int32`, `int64`, `hash64`
*   `int32` → `int64`
*   `float32` → `float64`
*   `float64` → `float32` (precision loss possible)
*   `[A]` → `[B]` (if `A` → `B` is valid)
*   `A?` → `B?` (if `A` → `B` is valid)

### Unsafe changes

The following changes will break compatibility:

*   Changing a field/variant number, or reordering fields/variants if using implicit numbering.
*   Changing the type of a field, wrapper variant, method request or method response to an incompatible type.
*   Changing a method's stable identifier.
*   Reusing a `removed` field or variant number.
*   Deleting a field or variant without marking it as `removed`.
*   Changing a constant variant to a wrapper variant or vice-versa.

### Automated compatibility checks

The Skir compiler includes a `snapshot` tool to prevent accidental breaking changes.

#### The snapshot workflow

The `npx skir snapshot` command helps you manage schema evolution by maintaining a history of your schema state.

When you run this command, two things happen:

1.  **Verification**: Skir checks for a `skir-snapshot.json` file. If it exists, it compares your current `.skir` files against it. If breaking changes are detected, the command reports them and exits.
2.  **Update**: If no breaking changes are found (or if no snapshot exists), Skir creates or updates the `skir-snapshot.json` file to reflect the current schema.

##### Recommended workflow

**1. During development**

While drafting a new schema version, use the `--dry` flag to check for backward compatibility without updating the snapshot:

```shell
npx skir snapshot --dry
```

This confirms that your changes are safe relative to the last release (snapshot).

**2. Before release**

Run `npx skir snapshot` without flags to verify compatibility and commit the new schema state to the snapshot file.

**3. Continuous integration**

Add the command to your CI pipeline or pre-commit hook to prevent accidental breaking changes. The `--ci` flag ensures the snapshot is up-to-date and compatible:

```yml
      - name: Ensure Skir snapshot up-to-date
        run: npx skir snapshot --ci
```

#### Tracked types and stable identifiers

To track compatibility across renames, Skir needs a stable identifier for your types. You can assign a random integer ID to any struct or enum:

```d
// "User" is now tracked by ID 500996846
struct User(500996846) {
  name: string;
}
```

If you rename `User` to `Account` but keep the ID `500996846`, Skir knows it's the same type and will validate the change safely.

**Best practice**: Assign stable identifiers to all root types used for storage. Nested types are implicitly tracked through their parents so you don't need to give them a stable identifier. Similarly, the request and response types of methods are automatically tracked as part of the method definition.

#### Handling intentional breaking changes

If you must make a breaking change (e.g., during early development), simply delete the `skir-snapshot.json` file and run `npx skir snapshot` again to establish a new baseline.

### Round-tripping unrecognized data

Consider a service in a distributed system that reads a Skir value, modifies it, and writes it back. If the schema has evolved (e.g., new fields were added) but the service is running older code, it may encounter data it doesn't recognize.

When deserializing, you can choose to either **drop** or **preserve** this unrecognized data.

*   **Drop (default)**: Unrecognized fields and variants are discarded. This is safer but results in data loss if the object is saved back to storage.
*   **Preserve**: Unrecognized data is kept internally and written back during serialization. This enables "round-tripping".

#### Example

Consider a schema evolution where a field and an enum variant are added:

**Version 1**:
```d
struct UserBefore(999) {
  id: int64;
  subscription_status: enum {
    FREE;
    PREMIUM;
  };
}
```

**Version 2**:
```d
struct UserAfter(999) {
  id: int64;
  subscription_status: enum {
    FREE;
    PREMIUM;
    TRIAL;  // Added
  };
  name: string;  // Added
}
```

The following TypeScript example illustrates what happens when `UserBefore` (old code) processes data created by `UserAfter` (new code):

```typescript
// Data created by new code
const originalJson = UserAfter.serializer.toJson(UserAfter.create({
  id: 123,
  subscription_status: "TRIAL",
  name: "Jane",
}));
```

##### Default behavior: drop

By default, unrecognized data is lost during the round-trip.

```typescript
// Old code reads and writes the data
const oldUser = UserBefore.serializer.fromJson(originalJson);
const roundTrippedJson = UserBefore.serializer.toJson(oldUser);

// New code reads the result
const result = UserAfter.serializer.fromJson(roundTrippedJson);

assert(result.id === 123);
assert(result.name === ""); // Lost: reset to default
assert(result.subscriptionStatus.union.kind === "UNKNOWN"); // Lost: became UNKNOWN
```

##### Preserve behavior

You can configure the deserializer to keep unrecognized values.

```typescript
// Old code reads with "keep-unrecognized-values"
const oldUser = UserBefore.serializer.fromJson(
  originalJson,
  "keep-unrecognized-values"
);
const roundTrippedJson = UserBefore.serializer.toJson(oldUser);

// New code reads the result
const result = UserAfter.serializer.fromJson(roundTrippedJson);

assert(result.id === 123);
assert(result.name === "Jane"); // Preserved!
assert(result.subscriptionStatus.union.kind === "TRIAL"); // Preserved!
```

> [!NOTE]
> Unrecognized data can only be preserved during round-trip conversion if the serialization format (dense JSON or binary) is the same as the deserialization format. If you read JSON and write binary, unrecognized data will be dropped even if you requested to keep it.

#### Security implications

> [!WARNING]
> **Only preserve unrecognized data from trusted sources.**
>
> Malicious actors could inject fields with IDs that you haven't defined yet. If you preserve this data and later define those IDs in a future version of your schema, the injected data could be deserialized as valid fields, potentially leading to security vulnerabilities or data corruption.


## Skir services

Skir provides a transport-agnostic RPC (Remote Procedure Call) framework that lets you define API methods in your schema and implement them in your preferred programming language.

Unlike many RPC frameworks that couple your code to a specific transport protocol or server implementation, Skir services are designed to be embedded within your existing application stack. See the following examples:
*   **Java**: [Spring Boot](https://github.com/gepheum/skir-java-example/blob/main/src/main/java/examples/StartService.java)
*   **Kotlin**: [Ktor](https://github.com/gepheum/skir-kotlin-example/blob/main/src/main/kotlin/startservice/StartService.kt)
*   **Dart**: [Shelf](https://github.com/gepheum/skir-dart-example/blob/main/lib/all_strings_to_upper_case.dart)
*   **Python**: [FastAPI](https://github.com/gepheum/skir-python-example/blob/main/start_service_fastapi.py), [Flask](https://github.com/gepheum/skir-python-example/blob/main/start_service_flask.py), or [Starlite](https://github.com/gepheum/skir-python-example/blob/main/start_service_starlite.py)
*   **TypeScript**: [Express](https://github.com/gepheum/skir-typescript-example/blob/main/src/server.ts)
*   **C++**: [httplib](https://github.com/gepheum/skir-cc-example/blob/main/service_start.cc)

Features like authentification, request logging or rate limiting are handled by the underlying framework.

#### Why use Skir services?

The primary advantage of using Skir services is **end-to-end type safety**.

In a traditional REST API, the contract between client and server is often implicit: *Send a JSON object with fields `x` and `y` to `/api/foo`, and receive a JSON object with field `z`.* This contract is fragile; if the server code changes the expected keys but the client isn't updated, the API breaks at runtime.

Skir enforces this contract at compile time. By defining your methods in a `.skir` schema, both your server implementation and your client calls are generated from the same source of truth. You cannot call a method that doesn't exist, pass the wrong arguments, or mishandle the response type without the compiler alerting you immediately.

> [!NOTE]
> Skir solves the same problem as [**tRPC**](https://trpc.io/), but it is **language-agnostic**. While tRPC is excellent for full-stack TypeScript applications, Skir brings that same level of developer experience and safety to polyglot environments (e.g., a TypeScript frontend talking to a Kotlin or Python backend).

#### Use cases

Skir services are versatile and can be used in two main contexts:
1.  **Microservices**: Similar to **gRPC**, Skir allows efficiently typed communication between backend services.
2.  **Browser-to-Backend**: Skir works seamlessly over standard HTTP/JSON, making it perfect for connecting a web frontend (React, Vue, etc.) to your backend.

### Defining methods

In Skir, a service is simply a collection of methods. You define methods in your `.skir` files using the `method` keyword.

```d
// Defines a method named 'GetUser' which takes a GetUserRequest and returns a GetUserResponse
method GetUser(GetUserRequest): GetUserResponse = 12345;
```

A method definition specifies the **request** type, the **response** type, and a stable numeric identifier.

> [!NOTE]
> Methods are defined globally in your schema. Skir does not group methods into "Service" blocks in the `.skir` file. You decide how to group and implement methods in your application code.

### Implementing a service

> *The examples below use Python, but the concepts apply identically to all supported languages.*

Skir provides a `Service` class in its runtime library for each supported language. This class acts as a central dispatcher that handles deserialization, routing, and serialization.

To create a service, you instantiate the `Service` class and register your method implementations.

#### 1. The `RequestMeta` concept

Skir services are generic over a `RequestMeta` type. This is a type you define to hold context information extracted from the HTTP request, such as authentication tokens, user sessions, or client IP addresses. This metadata is passed to your method implementations along with the request body.

```python
from dataclasses import dataclass
import skir

@dataclass
class RequestMeta:
    auth_token: str
    client_ip: str


# Create an async service typed with our metadata class
service = skir.ServiceAsync[RequestMeta]()
```

#### 2. Registering methods

You link the abstract method definitions generated from your schema to your actual code logic.

```python
from skirout.user import GetUser, GetUserRequest, GetUserResponse

async def get_user(req: GetUserRequest, meta: RequestMeta) -> GetUserResponse:
    # We have type-safe access to both the request fields and our metadata
    print(f"Request from IP: {meta.client_ip}")
    return GetUserResponse(user=await db.get_user(req.user_id))

# Typing error if the signature of get_user does not match GetUser.
service.add_method(GetUser, get_user)
```

### Running the service

Skir does not start its own HTTP server. Instead, it provides a `handle_request` method that you call from your existing web server's request handler.

This `handle_request` method takes:
1.  The raw request body (as a string).
2.  Your constructed `RequestMeta` object.

It returns a generated response containing the status code, content type, and body data, which you seamlessly write back to your HTTP client.

Since Skir manages the request body parsing and routing internally, you typically only need **one HTTP endpoint** (e.g., `/api`) to serve your entire API.

```python
# FastAPI example
from fastapi import FastAPI, Request
from fastapi.responses import Response

app = FastAPI()


@app.api_route("/myapi", methods=["GET", "POST"])
async def myapi(request: Request):
    # 1. Read body
    if request.method == "POST":
        req_body = (await request.body()).decode("utf-8")
    else:
        req_body = urllib.parse.unquote(
            request.url.query.encode("utf-8").decode("utf-8")
        )

    # 2. Build metadata from framework-specific request object
    req_meta = extract_meta_from_request(request)

    # 3. Delegate to Skir
    raw_response = await skir_service.handle_request(req_body, req_headers)

    # 4. Map back to framework response
    return Response(
        content=raw_response.data,
        status_code=raw_response.status_code,
        media_type=raw_response.content_type,
    )


def extract_meta_from_request(request: Request) -> RequestMeta:
    ...
```

### Calling a service

#### Using Skir clients

Skir generates a type-safe `ServiceClient` class that abstracts away the network layer. This ensures that your client code is always in sync with your API definition.

```python
from skir import ServiceClient
import aiohttp

# 1. Initialize the client with your service URL
client = ServiceClient("http://localhost:8000/api")

async def main():
    async with aiohttp.ClientSession() as session:
         # 2. Call methods directly using the generated definitions
        response = await client.invoke_remote_async(
            session,
            GetUser,
            GetUserRequest(user_id="u_123"),
            headers={"Authorization": "Bearer token"}
        )
        
        # 'response' is fully typed as 'GetUserResponse'
        print(response.user.name)
```

See examples for:
*   **Java**: [CallService.java](https://github.com/gepheum/skir-java-example/blob/main/src/main/java/examples/CallService.java)
*   **Kotlin**: [CallService.kt](https://github.com/gepheum/skir-kotlin-example/blob/main/src/main/kotlin/callservice/CallService.kt)
*   **Dart**: [call_service.dart](https://github.com/gepheum/skir-dart-example/blob/main/bin/call_service.dart)
*   **Python**: [call_service.py](https://github.com/gepheum/skir-python-example/blob/main/call_service.py)
*   **TypeScript**: [client.ts](https://github.com/gepheum/skir-typescript-example/blob/main/src/client.ts)
*   **C++**: [service_client.cc](https://github.com/gepheum/skir-cc-example/blob/main/service_client.cc)

#### Using cURL

You can also invoke Skir methods using any HTTP client by sending a POST request with a JSON body. The body must follow a specific structure identifying the method and its arguments.

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"method": "GetUser", "request": {"user_id": "u_123"}}' \
  http://localhost:8000/api
```

### Skir Studio

Every Skir service comes with a built-in interactive documentation and testing tool called **Skir Studio**.

To access it, simply visit your API endpoint in a browser with the `?studio` query parameter (e.g., `http://localhost:8000/api?studio`). Skir serves a lightweight HTML page that inspects your service, lists all available methods, and provides auto-generated forms to send test requests and view responses.

> [!TIP]
> If you are familiar with **Swagger UI** (common in the FastAPI ecosystem), Skir Studio fills the same role. It provides a dedicated, auto-generated web interface to explore your API schema and execute requests interactively.


## External dependencies

Skir allows you to import and use types defined in other Skir projects. This is primarily useful for sharing common data structures across multiple repositories. External dependencies are regular GitHub repositories that contain Skir definitions.

### Configuring dependencies

To add a dependency, open your `skir.yml` file and add an entry to the `dependencies` section. The key is the GitHub repository identifier (`owner/repo` prefixed with `@`), and the value is the Git tag or release version you want to use.

```yaml
dependencies:
  # https://github.com/gepheum/fantasy-game-skir-example/tree/v1.0.0
  "@gepheum/fantasy-game-skir-example": v1.0.0

  "@my-org/user-service-skir": v3.5.0
```

When you run `npx skir gen`, Skir will automatically fetch these dependencies and cache them in the `skir-external/` directory.

> **Note:** The `skir-external/` directory should be added to your `.gitignore`.

#### Transitive dependencies

Dependencies are transitive: if A depends on B, and B depends on C, then A implicitly depends on C. Skir will automatically download all transitive dependencies.

To ensure consistency, Skir strictly forbids version conflicts. If two dependencies (direct or transitive) require different versions of the same package, the compiler will report an error. You must resolve this conflict by ensuring all usages align on a single version.

### Importing types

Once a dependency is configured, you can import types from it using the `import` statement in your `.skir` files. The import path is the full path to the file within the dependency, prefixed with the package identifier.

```d
import Quest from "@gepheum/fantasy-game-skir-example/fantasy_game.skir";

struct QuestCollection {
  collection_name: string;
  quests: [Quest|quest_id];
}
```

### Code generation

For languages which allow `@` symbols in directory names (like JavaScript), the code generated from external dependencies is placed in `skirout/@{owner}/{repo}`:

```javascript
// Javascript

import { Quest } from "../skirout/@gepheum/fantasy-game-skir-example/fantasy_game.js"
```

For languages which require every directory name to be a valid identifier (like Python), the generated code is placed in `skirout/external/{owner}/{repo}`, with dashes replaced by underscores:

```python
# Python

from skirout.external.gepheum.fantasy_game_skir_example import fantasy_game_skir
```

### Private repositories

If your dependencies are hosted in private GitHub repositories, you need to provide a GitHub Personal Access Token so Skir can download them.

#### 1. Generate a token
Go to your GitHub settings and [generate a new Personal Access Token (Classic)](https://github.com/settings/tokens) with the `repo` scope (for full control of private repositories) or just `read:packages` if applicable, though usually `repo` is needed for private source code access.

#### 2. Set the environment variable
Set an environment variable with your token. For example:

```bash
export MY_GITHUB_TOKEN=ghp_...
```

#### 3. Configure skir.yml
Tell Skir which environment variable to look for in your `skir.yml`:

```yaml
# skir.yml
githubTokenEnvVar: MY_GITHUB_TOKEN
```

Skir will now read the token from `MY_GITHUB_TOKEN` to authenticate requests.

#### 4. Set up GitHub Actions CI

When running Skir in a Continuous Integration (CI) environment like GitHub Actions, you can use the built-in `${{ secrets.GITHUB_TOKEN }}` to access other repositories within the same organization, or use a repository secret if you need broader access.

Here is an example workflow step:

```yaml
steps:
  - uses: actions/checkout@v3

  - name: Install dependencies and generate code
    run: npx skir gen
    env:
      # Pass the token to the environment variable configured in skir.yml
      MY_GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Important:** If the dependency is in a different private repository that the default `GITHUB_TOKEN` cannot access, you will need to create a Personal Access Token (PAT), store it as a Repository Secret (e.g., `PAT_TOKEN`), and use that instead:

```yaml
    env:
      MY_GITHUB_TOKEN: ${{ secrets.PAT_TOKEN }}
```
