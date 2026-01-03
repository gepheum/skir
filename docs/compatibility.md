# Schema evolution & compatibility

Skir is built with a **"serialize now, deserialize in 100 years"** philosophy. At its core, Skir makes it easy to maintain both backward and forward compatibility as your schemas evolve over time.

## The core concepts

Compatibility in Skir is divided into two categories:

### Backward compatibility

The ability of **new code to read old data**. This is relevant even for single-service architectures where you must deserialize records stored in a database months or years ago.

### Forward compatibility

The ability of **old code to read new data**. This is a primary challenge in distributed systems, where services (like mobile apps or microservices) are updated at different times. It ensures that an older binary does not fail when it encounters data containing fields it does not yet recognize.

## Schema evolution

### Safe changes

You can safely make these changes to a schema without breaking either backward or forward compatibility.

#### Add fields to a struct

When you add a field to a struct, Skir maintains backward compatibility by providing **default values** for any missing fields during deserialization. The default value depends on the type:

* **Numeric types:** `0`
* **Timestamps:** Unix epoch (Jan 1, 1970)
* **Strings and byte strings:** an empty string or byte string
* **Structs:** An empty struct: all fields at their own defaults
* **Enums:** The implicit `UNKNOWN` variant
* **Optional types:** `null`
* **Array types:** `[]`

#### Add variants to an enum

Forward compatibility: when an older binary encounters a variant it does not recognize, it automatically resolves to the implicit `UNKNOWN` variant.

#### Mark fields and variants as `removed`

#### Rename types, fields and variants

Renaming a struct, enum, field, variant is always legal. Because Skir identifies elements by their index numbers in both the *binary* and *dense JSON* formats, these human-readable names are not included in the serialized data. 

> [!NOTE] While names are included in the *readable JSON* format, this format is intended for debugging and inspection only; it is not recommended for long-term persistence or cross-system communication.

#### Switch to compatible types

You can change the type of a field, wrapper variant, method request, or method response, provided the new type is **backward compatible** with the old one. These rules define what type conversions are authorized:

*   `bool` → `int32` | `int64` | `uint64`
*   `int32` → `int64`
*   `float32` → `float64`
*   `float64` → `float32`
*   `[A]` → `[B]` assuming `A` → `B` is authorized
*   `A?` → `B?` assuming `A` → `B` is authorized

### Unsafe changes

All these schema changes can break either backward compatibility (new code won't be able to deserialize old data) or forward compatibility (old code won't be able to deserialize new data):

*   Change the number of a field, or reorder fields if you use implicit numbering
*   Change the type of a field, wrapper variant, method request or method response to a type that is not compatible
*   Change the stable identifier (number) of a method; or if the method is not explicitly given a number, rename it or move it to a different module
*   Reintroduce a field or variant number which was marked as `removed`. Removed numbers are forever.
*   Remove a field from a struct or a variant from an enum without marking the field/variant number as `removed`
*   Turn a constant variant into an enum variant or vice-versa

## Automatically verify the safety of schema evolution

The `snapshot` command of the Skir compiler allows you to make sure you're not introducing changes which could break backward of forward compatibility. A *snapshot* refers to an imprint of all your `.skir` files at a given time *t*.

Two things happen when you run:

```shell
npx skir snapshot
```

First, Skir checks if you already have a snapshot file (`skir.snapshot.json`) in your root directory. If you do, it looks for breaking changes between your old snapshot and your `.skir` files now. If there are breaking changes, the program prints a readable description of the breaking changes and exits. If there are no breaking changes, a new snapshot file is created.

### Tracked types

Because structs and enums can be renamed, in order to know whether a change to a type definition is safe, Skir needs a stable identifier for this type.

Consider this file at *t0*:

```d
struct Foo {
  b: bool;
}
```

And at *t1*:

```d
struct Bar {
  b: bool;
}

struct Zoo {
  s: string;
}
```

If `Foo` got renamed to `Bar`: the change is safe. But if it got renamed to `Zoo`, it's a breaking change because a `bool` field cannot be turned into a `string` field.

To solve this problem, Skir lets you set a stable identifier in a form of a meaningless (random) number when you define a type.

```d
struct Foo(500996846) {
  b: bool;
}
```

When you rename a type, you leave the stable identifier unchanged:

```d
struct Bar(500996846) {
  b: bool;
}
```

Now Skir knows that the change is safe: `Foo` was simply renamed to `Zoo`.

Assigning a stable identifier to a type definition make the type *tracked*. Other types which are automatically tracked are types used as RPC method requests or responses. When verifying whether a change is safe, `npx skir snapshot` only looks at tracked types.

#### What types to track

You should assign a stable identifier to all types that you intend to serialize and store on disk or in a databse. You do not need to do this recursively for all the types of their fields or variants, because when a type is tracked, the types of fields and variants are implicitly tracked as well. In other words, you only need to track a type `T` if you explicitly call the generated Skir serialization method expecting a `T`.

### Suggested workflow

(BEFORE RELASING)
(DRAFTING)

### Moving forward with unsafe changes

(DELETING THE FILE)

## Forward compatibility and round-tripping

Consider a service, in a distributed system, which reads a Skir value from a given source (e.g. an HTTP request), modifies it, then writes it back somewhere else. What happens if the schema has evolved (e.g. new fields were added), but the service still runs with the old code, and it encounters new data?

You can chose one of two options: drop or preserve the data which was not present in the old schema. This option must be specified at deserialization time. The default option is to drop. This feature exists in all languages.

Let's consider this schema:

```d
struct UserBefore {
  id: int64;
  subscription_status: enum {
    FREE;
    PREMIUM;
  };
}
```

Let's evolve this schema by adding a field to the struct and a variant to the enum:

```d
struct UserAfter {
  id: int64;
  subscription_status: enum {
    FREE;
    PREMIUM;
    TRIAL;  // New variant
  };
  name: string;  // New field
}
```

This TypeScript example illustrates what happens when the old code tries to deserialize and reserialize new data:

```typescript
const user = UserAfter.create({
  id: 123,
  subscription_status: "TRIAL",
  name: "Jane",
});

const userJson = UserAfter.serializer.toJson(user);
```

Default option - unrecognized data is dropped:

```typescript
const newUser = UserAfter.serializer.fromJson(
  UserBefore.serializer.toJson(
    UserBefore.serializer.fromJson(
      userJson
    )
  )
);

assert(newUser.id === 123);
assert(newUser.name === "");  // Default value for string fields
assert(newUser.subscriptionStatus.union.kind === "?");  // UNKNOWN variant
```

Option to keep unrecognized data at deserialization:

```typescript
const newUser = UserAfter.serializer.fromJson(
  UserBefore.serializer.toJson(
    UserBefore.serializer.fromJson(
      userJson,
      "keep-unrecognized-values",  // <- this
    )
  )
);

assert(newUser.id === 123);
assert(newUser.name === "Jane");
assert(newUser.subscriptionStatus.union.kind === "TRIAL");
```

Note that unrecognized data can only be preserved during round-trip conversion if the serialization format (dense JSON or binary) is the same as the deserialization format.

```typescript
const newUser = UserAfter.serializer.fromBytes(
  UserBefore.serializer.toBytes(  // JSON -> bytes: dropped here
    UserBefore.serializer.fromJson(
      userJson,
      "keep-unrecognized-values",
    )
  )
);

assert(newUser.id === 123);
assert(newUser.name === "");  // The unrecognized field was dropped
```

### When to chose to preserve unrecognized data

While it can seem like a benefit to always preserve unrecognized data, it comes with a security risk: you should **only keep unrecognized data if the data comes from a source you trust**. The reason is that a malicious user could send data which conforms to the current schema but also contains field numbers which don't exist yet in your schema. If you later add these field numbers to your schema, bad things will happen when you try to deserialize these old values.

