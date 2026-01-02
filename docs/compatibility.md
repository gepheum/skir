# Schema evolution & compatibility

Skir is built with a **"serialize now, deserialize in 100 years"** philosophy. At its core, Skir makes it easy to maintain both backward and forward compatibility as your schemas evolve over time.

## The core concepts

Compatibility in Skir is divided into two categories:

### Backward compatibility

The ability of **new code to read old data**. This is relevant even for single-service architectures where you must deserialize records stored in a database months or years ago.

### Forward compatibility

The ability of **old code to read new data**. This is a primary challenge in distributed systems, where services (like mobile apps or microservices) are updated at different times. It ensures that an older binary does not fail when it encounters data containing fields it does not yet recognize.

## Schema evolution

### What you can do

#### Add fields to a struct

When you add a field to a struct, Skir maintains backward compatibility by providing **default values** for any missing fields during deserialization. The default value depends on the type:

* **Numeric types:** `0`
* **Timestamps:** Unix epoch (Jan 1, 1970)
* **Strings and byte strings:** an empty string or byte string
* **Structs:** An empty struct (all fields at their own defaults)
* **Enums:** The implicit `UNKNOWN` variant
* **Optional types:** `null`
* **Array types:** `[]`

#### Add variants to an enum

Forward compatibility: when an older binary encounters a variant it does not recognize, it automatically resolves to the implicit `UNKNOWN` variant.

#### Mark fields and variants as `removed`

Forward compatibility: when a field is retired using the `removed` keyword, newer binaries will write a special value for that field number during serialization. An older binary that encounters this special value will decode it based on the field's type:

* **Non-optional type**: resolves to the type's default value (e.g., `0` or `""`).
* **Optional type (`T?`)**: resolves to either the default value of the underlying type `T` or `null`.

#### Rename things

Renaming a struct, enum, field, variant, or module — as well as moving definitions between modules — is always legal. Because Skir identifies elements by their index numbers in both the *binary* and *dense JSON* formats, these human-readable names are not included in the serialized data. 

> [!NOTE] While names are included in the *readable JSON* format, this format is intended for debugging and inspection only; it is not recommended for long-term persistence or cross-system communication.

#### Switch to compatible types

You can change the type of a field, wrapper variant, method request, or method response, provided the new type is **compatible** with the old one. Compatibility is defined by these rules:

* **Integrals:** all integer-based types (`bool`, `int32`, `int64`, and `uint64`) are mutually compatible.
* **Floating-point:** `float32` and `float64` are mutually compatible.
* **Arrays:** `[A]` and `[B]` are compatible if types `A` and `B` are compatible.
* **Optionals:** `A?` and `B?` are compatible if types `A` and `B` are compatible.

> [!WARNING]
> **Potential Data Loss**
> While these types are compatible for serialization, changing them may result in data loss or truncation during conversion:
> * **Downcasting:** Converting from `int64` to `int32` may cause overflow if the value exceeds the smaller type's range.
> * **Precision:** Converting between floating-point types or between integers and floats may lead to rounding differences.
>
> This loss can occur in both directions: when new binaries read legacy data (e.g., an old `int64` into a new `int32`) and when older binaries read newer data (e.g., a new `int64` into an old `int32`).

### What you can **not** do

TODO

### Handling unrecognized data

