## Serialization formats

When serializing a data structure, you can chose one of 3 formats.

Note that when Skir *deserializes* JSON, it knows how to handle both dense and readable flavor. It's only when *serializing* JSON that a flavor must be specified.

### JSON, dense flavor

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

### JSON, readable flavor

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

### Binary format

This format is a bit more compact than JSON, and serialization/deserialization can be faster in languages like C++. Only prefer this format over JSON when the small performance gain is likely to matter, which should be rare.

## Implementation details

This section describes precisely how each data type is serialized to each of the 3 formats. This information is intended for advanced users who want to understand the inner workings of Skir, or for developers who want to implement a Skir generator for a new programming language.

### Handling of Zeros

Since the dense JSON and binary format use zeros to represent `removed` fields, in order to preserve forward compatibility, zero is a valid input for any type even non-numerical types. With the exception of the optional type, all types will decode "zero" as the default value for the type (e.g. an empty array). The optional type will decode zero as the default value of the underlying type.

### Primitives

#### Bool

*   **JSON (Readable)**: `true` or `false`.
*   **JSON (Dense)**: `1` for true, `0` for false.
*   **Binary**: A single byte: `1` for true, `0` for false.

#### Int32

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

#### Int64

*   **JSON**:
    *   If the value is within the safe integer range for JavaScript (±9,007,199,254,740,991), it is serialized as a JSON number.
    *   Otherwise, it is serialized as a string.
*   **Binary**:
    *   `0`: Encoded as a single byte `0`.
    *   If the value fits in an `int32`, it uses the `int32` encoding described above.
    *   Otherwise: Encoded as byte `238` followed by a little-endian `int64`.

#### Hash64

*   **JSON**: Same rule as `int64` (number if safe, string otherwise).
*   **Binary**:
    *   `0` to `231`: Encoded as a single byte with that value.
    *   `232` to `4,294,967,295`: Uses the `int32` positive encoding (byte `232` + `uint16` or byte `233` + `uint32`).
    *   `4,294,967,296` and above: Encoded as byte `234` followed by a little-endian `uint64`.

#### Float32 and Float64

*   **JSON**:
    *   Finite numbers are serialized as JSON numbers.
    *   `NaN`, `Infinity`, and `-Infinity` are serialized as strings: `"NaN"`, `"Infinity"`, `"-Infinity"`.
*   **Binary**:
    *   `0`: Encoded as a single byte `0`.
    *   **Float32**: Encoded as byte `240` followed by a little-endian `float32`.
    *   **Float64**: Encoded as byte `241` followed by a little-endian `float64`.

#### Timestamp

*   **JSON (Readable)**: An object with two fields:
    *   `unix_millis`: The number of milliseconds since the Unix epoch.
    *   `formatted`: An ISO 8601 string representation. Note that when deserializing, only the `unix_millis` field is read.
*   **JSON (Dense)**: A JSON number representing the milliseconds since the Unix epoch.
*   **Binary**:
    *   `0` (Epoch): Encoded as a single byte `0`.
    *   Otherwise: Encoded as byte `239` followed by a little-endian `int64` (milliseconds).

#### String

*   **JSON**: A JSON string.
*   **Binary**:
    *   Empty string: Encoded as byte `242`.
    *   Non-empty: Encoded as byte `243`, followed by the length of the UTF-8 sequence (encoded using the positive `int32` rules: byte, `232`+u16, or `233`+u32), followed by the UTF-8 bytes.

#### Bytes

*   **JSON (Readable)**: The string "hex:" followed by the hexadecimal string.
*   **JSON (Dense)**: A Base64 string.
*   **Binary**:
    *   Empty: Encoded as byte `244`.
    *   Non-empty: Encoded as byte `245`, followed by the length (encoded using `int32` rules), followed by the raw bytes.

### Complex Types

#### Optional

*   **JSON**: `null` if the value is missing, otherwise the serialized value.
*   **Binary**:
    *   `null`: Encoded as byte `255`.
    *   Value: The serialized value directly.

#### Array

*   **JSON**: A JSON array.
*   **Binary**:
    *   Length `0` to `3`: Encoded as byte `246 + length` (i.e., `246`, `247`, `248`, `249`).
    *   Length `4` and above: Encoded as byte `250`, followed by the length (encoded using `int32` rules).
    *   The items follow immediately after the length marker.

#### Struct

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

#### Enum

*   **JSON (Readable)**:
    *   **Constant variant**: The name of the variant (string), e.g. `"MONDAY"`.
    *   **Wrapper variant**: An object `{ "kind": "variant_name", "value": ... }`.
    *   **Unknown**: The string `"?"`.
*   **JSON (Dense)**:
    *   **Constant variant**: The variant number (integer).
    *   **Wrapper variant**: An array `[variant_number, value]`.
    *   **Unknown**: `0`.
*   **Binary**:
    *   **Unknown**: Encoded as byte `0`.
    *   **Constant variant**: Encoded using the `int32` positive number rules (byte, `232`+u16, etc.).
    *   **Wrapper variant**:
        *   Variant number `1` to `4`: Encoded as byte `250 + number` (i.e., `251`, `252`, `253`, `254`).
        *   Variant number `5` and above: Encoded as byte `248`, followed by the variant number (encoded using `int32` rules).
        *   The value follows immediately.

