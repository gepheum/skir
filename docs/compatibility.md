# Schema evolution & compatibility

Skir is designed for long-term data persistence and distributed systems. It ensures that your application can evolve its data structures while maintaining compatibility with older data (backward compatibility) and older clients (forward compatibility).

## Core concepts

*   **Backward compatibility**: New code can read old data. This is essential for reading records stored in a database created with an older schema.
*   **Forward compatibility**: Old code can read new data. This is critical in distributed systems where different services or clients may be running different versions of your application.

## Safe schema changes

The following changes are safe and preserve both backward and forward compatibility:

### 1. Adding fields to a struct
New code reading old data will use default values for missing fields:
*   **Numbers**: `0`
*   **Booleans**: `false`
*   **Strings/Bytes**: Empty string/bytes
*   **Arrays**: Empty array `[]`
*   **Structs**: A struct with all fields at their default values
*   **Enums**: The implicit `UNKNOWN` variant
*   **Optional types**: `null`

### 2. Adding variants to an enum
Old code encountering a new variant will treat it as the implicit `UNKNOWN` variant.

### 3. Renaming types, fields, and variants
Skir uses numeric identifiers (field numbers) in its binary and compact JSON formats, not names. Therefore, renaming any element is safe.

> [!NOTE]
> Names *are* used in the human-readable JSON format. This format is for debugging only and should not be used for storage or inter-service communication.

### 4. Removing fields or variants
You must mark the field or variant number as `removed` to prevent accidental reuse.

### 5. Compatible type changes
You can change a type if the new type is backward-compatible with the old one:
*   `bool` → `int32`, `int64`, `hash64`
*   `int32` → `int64`
*   `float32` → `float64`
*   `float64` → `float32` (precision loss possible)
*   `[A]` → `[B]` (if `A` → `B` is valid)
*   `A?` → `B?` (if `A` → `B` is valid)

## Unsafe changes

The following changes will break compatibility:

*   Changing a field/variant number, or reordering fields/variants if using implicit numbering.
*   Changing the type of a field, wrapper variant, method request or method response to an incompatible type.
*   Changing a method's stable identifier.
*   Reusing a `removed` field or variant number.
*   Deleting a field or variant without marking it as `removed`.
*   Changing a constant variant to a wrapper variant or vice-versa.

## Automated compatibility checks

The Skir compiler includes a `snapshot` tool to prevent accidental breaking changes.

### The snapshot workflow

The `npx skir snapshot` command helps you manage schema evolution by maintaining a history of your schema state.

When you run this command, two things happen:

1.  **Verification**: Skir checks for a `skir_snapshot.json` file. If it exists, it compares your current `.skir` files against it. If breaking changes are detected, the command reports them and exits.
2.  **Update**: If no breaking changes are found (or if no snapshot exists), Skir creates or updates the `skir_snapshot.json` file to reflect the current schema.

#### Recommended workflow

**1. During Development**

While drafting a new schema version, use the `--dry` flag to check for backward compatibility without updating the snapshot:

```shell
npx skir snapshot --dry
```

This confirms that your changes are safe relative to the last release (snapshot).

**2. Before Release**

Run `npx skir snapshot` without flags to verify compatibility and commit the new schema state to the snapshot file.

**3. Continuous Integration**

Add the command to your CI pipeline or pre-commit hook to prevent accidental breaking changes. The `--ci` flag ensures the snapshot is up-to-date and compatible:

```yml
      - name: Ensure Skir snapshot up-to-date
        run: npx skir snapshot --ci
```

### Tracked types and stable identifiers

To track compatibility across renames, Skir needs a stable identifier for your types. You can assign a random integer ID to any struct or enum:

```d
// "User" is now tracked by ID 500996846
struct User(500996846) {
  name: string;
}
```

If you rename `User` to `Account` but keep the ID `500996846`, Skir knows it's the same type and will validate the change safely.

**Best Practice**: Assign stable identifiers to all root types used for storage. Nested types are implicitly tracked through their parents so you don't need to give them a stable identifier. Similarly, the request and response types of methods are automatically tracked as part of the method definition.

### Handling intentional breaking changes

If you must make a breaking change (e.g., during early development), simply delete the `skir_snapshot.json` file and run `npx skir snapshot` again to establish a new baseline.

## Round-tripping unrecognized data

Consider a service in a distributed system that reads a Skir value, modifies it, and writes it back. If the schema has evolved (e.g., new fields were added) but the service is running older code, it may encounter data it doesn't recognize.

When deserializing, you can choose to either **drop** or **preserve** this unrecognized data.

*   **Drop (Default)**: Unrecognized fields and variants are discarded. This is safer but results in data loss if the object is saved back to storage.
*   **Preserve**: Unrecognized data is kept internally and written back during serialization. This enables "round-tripping".

### Example

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

#### Default Behavior: Drop

By default, unrecognized data is lost during the round-trip.

```typescript
// Old code reads and writes the data
const oldUser = UserBefore.serializer.fromJson(originalJson);
const roundTrippedJson = UserBefore.serializer.toJson(oldUser);

// New code reads the result
const result = UserAfter.serializer.fromJson(roundTrippedJson);

assert(result.id === 123);
assert(result.name === ""); // Lost: reset to default
assert(result.subscriptionStatus.union.kind === "?"); // Lost: became UNKNOWN
```

#### Preserve Behavior

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

### Security Implications

> [!WARNING]
> **Only preserve unrecognized data from trusted sources.**
>
> Malicious actors could inject fields with IDs that you haven't defined yet. If you preserve this data and later define those IDs in a future version of your schema, the injected data could be deserialized as valid fields, potentially leading to security vulnerabilities or data corruption.
