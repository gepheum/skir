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
*   Changing a method's stable identifier (or renaming/moving a method without an explicit ID).
*   Reusing a `removed` field or variant number.
*   Deleting a field or variant without marking it as `removed`.
*   Changing a constant variant to a wrapper variant or vice-versa.

## Automated compatibility checks

The Skir compiler includes a snapshot tool to prevent accidental breaking changes.

### The snapshot workflow

1.  **Create/Update Snapshot**: Run `npx skir snapshot` to create a `skir.snapshot.json` file representing your current schema state.
2.  **Verify Changes**: Subsequent runs compare your current `.skir` files against this snapshot. If a breaking change is detected, the command fails and reports the issue.
3.  **CI Integration**: Add `npx skir snapshot --ci` to your CI pipeline to enforce compatibility checks on every commit.

### Tracked types and stable identifiers

To track compatibility across renames, Skir needs a stable identifier for your types. You can assign a random integer ID to any struct or enum:

```d
// "User" is now tracked by ID 500996846
struct User(500996846) {
  name: string;
}
```

If you rename `User` to `Account` but keep the ID `500996846`, Skir knows it's the same type and will validate the change safely.

**Best Practice**: Assign stable identifiers to all root types used for storage or RPC. Nested types are implicitly tracked through their parents.

### Handling intentional breaking changes

If you must make a breaking change (e.g., during early development), simply delete the `skir.snapshot.json` file and run `npx skir snapshot` again to establish a new baseline.

## Round-tripping unknown data

When an older client reads data with new fields, it can either **drop** or **preserve** the unknown data when re-serializing.

*   **Drop (Default)**: Unknown fields are discarded. This is safer but may result in data loss if the object is saved back to storage.
*   **Preserve**: Unknown fields are kept and written back. This enables "round-tripping" but carries security risks.

> [!NOTE]
> Unrecognized data can only be preserved during round-trip conversion if the serialization format (dense JSON or binary) is the same as the deserialization format.

### Example

**Schema Evolution**:
*   v1: `struct User { id: int64; }`
*   v2: `struct User { id: int64; name: string; }`

**Scenario**: A v1 service receives a v2 object (`{id: 1, name: "Alice"}`).

**Default Behavior (Drop)**:
The v1 service deserializes it to `{id: 1}`. If it saves the object, `name` is lost.

**Preserve Behavior**:
You can configure the deserializer to keep unknown fields.

```typescript
// TypeScript example
const user = User.serializer.fromJson(json, "keep-unrecognized-values");
// user.name is not accessible in code, but is stored internally.
const newJson = User.serializer.toJson(user);
// newJson contains "name": "Alice"
```

> [!WARNING]
> Only preserve unknown data from trusted sources. Malicious actors could inject fields with IDs that you haven't defined yet, potentially causing issues if you define those IDs in a future version.
