# Skir language reference

## Records

There are two types of records: structs and enums.

### Structs

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

### Enums

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

### Nesting records

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

### Inline records

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

### Removed numbers

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

### Stable identifiers

You can assign a numeric stable identifier to a struct or an enum by specifying it in parentheses after the record name:

```d
struct Point(23456) { ... }
```

This identifier is used by the `npx skir snapshot` command to track record identity across renames and detect breaking changes. For more information, see the [compatibility guide](compatibility.md).

No two types in your Skir project can have the same stable identifier.

> [!TIP]
> You can use `?` as a placeholder for the identifier and run `npx skir format`. It will replace the question mark with a generated random number. This replacement happens automatically on save if you are using the [VSCode extension](https://marketplace.visualstudio.com/items?itemName=TylerFibonacci.skir-language).

### Recursive records

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

## Data types

### Primitive types

*   `bool`: true or false
*   `int32`: a signed 32-bit integer
*   `int64`: a signed 64-bit integer
*   `hash64`: an unsigned 64-bit integer; prefer using this for hash codes and `int64` for numbers which represent an actual *count*
*   `float32`: a 32-bit floating point number; can be one of `NaN`, `Infinity` or `-Infinity`
*   `float64`: a 64-bit floating point number; can be one of `NaN`, `Infinity` or `-Infinity`
*   `string`: a Unicode string
*   `bytes`: a sequence of bytes
*   `timestamp`: a specific instant in time represented as an integral number of milliseconds since the Unix epoch, from 100M days before the Unix epoch to 100M days after the Unix epoch

### Array type

Wrap the item type inside square brackets to represent an array of items, e.g. `[string]` or `[User]`.

#### Keyed arrays

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

### Optional type

Add a question mark at the end of a non-optional type to make it optional. An `other_type?` value is either an `other_type` or null.

## Constants

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

## Methods (RPCs)

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

### Stable identifiers

Every method must have a unique integer identifier (e.g. `= 12345`) used for RPC routing. This identifier decouples the method's identity from its name, allowing safe renaming and refactoring without breaking compatibility with older clients.

No two methods in your Skir project can have the same stable identifier.

> [!TIP]
> You can use `?` as a placeholder for the identifier and run `npx skir format`. It will replace the question mark with a generated random number. This replacement happens automatically on save if you are using the [VSCode extension](https://marketplace.visualstudio.com/items?itemName=TylerFibonacci.skir-language).

### Inline request/response records

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

## Imports

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

## Doc comments

Doc comments are designated by three forward slashes (`///`) and are used to provide high-level documentation for records, fields, and methods. Unlike regular comments (`//` or `/*`), which are ignored by the compiler, doc comments are processed as part of your schema definition.

### Referencing symbols

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

### Integration with code generators

One of the primary advantages of doc comments is that they are copied directly into the generated code. Developers using IDEs like VSCode or IntelliJ will see your documentation in hover information, code completion, and inlay hints.

### RPC visibility and security

When documenting types used as a request or response for an RPC method, be aware that these comments may be visible to any user or client with access to that interface.

For this reason, it is critical **not** to include business-confidential information, internal server paths, or sensitive security logic in doc comments for types that will be exposed via public-facing services.
