# Serialization

Skir defines a standard for serializing and deserializing data types to JSON and binary. The generated data classes implement this standard to ensure that data structures defined in your schema can be encoded and decoded consistently across all languages.

## Serialization formats

When serializing a data structure, you can choose one of 3 formats:

| Format        | Persistable | Space efficiency | Readability |
| ------------- | ----------- | ---------------- | ----------- |
| Dense JSON    | Yes (safe)  | High             | Low         |
| Readable JSON | No (unsafe) | Low              | High        |
| Binary        | Yes (safe)  | Very High        | None        |

### Dense JSON

This is the format you should choose in most cases. It is compact and safe for persistence — you can freely rename fields in your schema without breaking compatibility with existing data.

Structs are serialized as JSON arrays, where the field numbers in the index definition match the indexes in the array. Constant variants of enums are serialized as numbers, wrapper variants are serialized as [number, value] arrays.

```skir
struct User {
  user_id: int32;
  removed;
  name: string;
  rest_day: Weekday;
  subscription_status: SubscriptionStatus;
  pets: [Pet];
  nickname: string;
}

const JOHN_DOE: User = {
  user_id: 400,
  name: "John Doe",
  rest_day: "sunday",
  subscription_status: {
    kind: "premium_since",
    value: "2027-01-01:00:00:00Z",
  },
  pets: [
    { name: "Fluffy" },
    { name: "Fido" },
  ],
  nickname = "",
}
```

The dense JSON representation of `JOHN_DOE` is:

```json
[400, 0, "John Doe", 7, [2, 1798761600000], [["Fluffy"], ["Fido"]]]
```

Removed fields are replaced with zeros. Trailing fields with default values ( `nickname` in this example) are omitted.

The output is compact but not human-friendly — if you query a column storing dense JSON directly with a `SELECT`, what comes back is a terse array of numbers and values with no field names in sight. If you ever need to inspect a value during debugging, a tool that can come in very handy is the [Converter](#converter-web-app) web app, which can translate any dense JSON value into readable JSON instantly.

#### Encoding rules

| Type                                  | Encoded as                                                                                                                                                             | Examples                                      |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| bool                                  | `1` for true, `0` for false                                                                                                                                            | <div>1</div>                                  |
| int32                                 | A JSON number                                                                                                                                                          | 1234                                          |
| <div>int64</div> <div>hash64</div>    | If the value is within the safe integer range for JavaScript (±9,007,199,254,740,991), it is serialized as a JSON number. <br>Otherwise, it is serialized as a string. | <div>1234</div> <div>"9007199254740992"</div> |
| <div>float32</div> <div>float64</div> | Finite numbers are serialized as JSON numbers.<br> `NaN`, `Infinity`, and `-Infinity` are serialized as strings.                                                       | <div>1.23</div> <div>"Infinity"</div>         |
| timestamp                             | A JSON number representing milliseconds since the Unix epoch                                                                                                           | 1672531200000                                 |
| string                                | A JSON string                                                                                                                                                          | "Hello"                                       |
| bytes                                 | A Base64 string                                                                                                                                                        | "SGVsbG8="                                    |
| T?                                    | `null` if the value is missing, otherwise the serialized value.                                                                                                        | <div>null</div> <div>123</div>                |
| [T]                                   | A JSON array                                                                                                                                                           | [1, 2, 3]                                     |
| struct                                | A JSON array. The array index corresponds to the field number. Removed fields are represented as `0`. Trailing default values are omitted.                             | [400, 0, "John"]                              |
| enum                                  | Constant variants are serialized as integers.<br> Wrapper variants are serialized as arrays with two elements: the variant number, the value.                          | <div>1</div> <div>[2, "value"]</div>          |

### Readable JSON

This format is intended for debugging and human inspection. Structs are serialized as JSON objects and enum constants as strings, making the output easy to read. However, it is **not safe for persistence**: because Skir allows fields to be renamed, schema evolution will silently break compatibility with old readable JSON data.

The readable JSON representation of `JOHN_DOE` is:

```json
{
  "user_id": 400,
  "name": "John Doe",
  "rest_day": "sunday",
  "subscription_status": {
    "kind": "premium_since",
    "value": {
      "unix_millis": 1798761600000,
      "formatted": "2027-01-01:00:00:00Z"
    }
  },
  "pets": [
    {
      "name": "Fluffy"
    },
    {
      "name": "Fido"
    }
  ]
}
```

#### Encoding rules

| Type                                  | Encoded as                                                                                                                                                             | Examples                                                                |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| bool                                  | `true` or `false`                                                                                                                                                      | <div>true</div>                                                         |
| int32                                 | A JSON number                                                                                                                                                          | 1234                                                                    |
| <div>int64</div> <div>hash64</div>    | If the value is within the safe integer range for JavaScript (±9,007,199,254,740,991), it is serialized as a JSON number. <br>Otherwise, it is serialized as a string. | <div>1234</div> <div>"9007199254740992"</div>                           |
| <div>float32</div> <div>float64</div> | Finite numbers are serialized as JSON numbers.<br> `NaN`, `Infinity`, and `-Infinity` are serialized as strings.                                                       | <div>1.23</div> <div>"Infinity"</div>                                   |
| timestamp                             | An object with `unix_millis` and `formatted` fields                                                                                                                    | `{ "unix_millis": 1672531200000, "formatted": "2023-01-01T00:00:00Z" }` |
| string                                | A JSON string                                                                                                                                                          | "Hello"                                                                 |
| bytes                                 | The string "hex:" followed by the hexadecimal representation                                                                                                           | "hex:48656c6c6f"                                                        |
| T?                                    | `null` if the value is missing, otherwise the serialized value.                                                                                                        | <div>null</div> <div>123</div>                                          |
| [T]                                   | A JSON array                                                                                                                                                           | [1, 2, 3]                                                               |
| struct                                | A JSON object containing field names and values. Default values are omitted.                                                                                           | `{ "name": "John", "age": 30 }`                                         |
| enum                                  | Constant variants are serialized as strings.<br> Wrapper variants are serialized as objects with `kind` and `value` fields.                                            | <div>"red"</div> <div>`{ "kind": "rgb", "value": "ff0000" }`</div>      |

### Binary format

This format is a bit more compact than JSON, and serialization/deserialization can be faster in languages like C++. Only prefer this format over JSON when the small performance gain is likely to matter, which should be rare.

#### Encoding rules

All numeric values are encoded using little-endian byte order.

| Type      | Encoded as                                                                                                                                                                                                                                                                                   | Examples                                                                          |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| bool      | `1` for true, `0` for false                                                                                                                                                                                                                                                                  | <div>0x01</div> <div>0x00</div>                                                   |
| int32     | 0-231: single byte `val` <br> 232-65535: `0xe8` followed by `uint16(val)` <br> ≥ 65536: `0xe9` followed by `uint32(val)` <br> -256 to -1: `0xeb` followed by `uint8(val + 256)` <br> -65536 to -257: `0xec` followed by `uint16(val + 65536)` <br> ≤ -65537: `0xed` followed by `int32(val)` | <div>10 -> 0x0a</div> <div>255 -> 0xe8 0xff 0x00</div> <div>-1 -> 0xeb 0xff</div> |
| int64     | If the value fits in a 32-bit signed integer, uses the `int32` encoding. <br> Otherwise: marker `0xee` followed by 8 bytes (int64).                                                                                                                                                          |                                                                                   |
| hash64    | If the value fits in a 32-bit unsigned integer, uses the `int32` encoding. <br> Otherwise: marker `0xea` followed by 8 bytes (uint64).                                                                                                                                                       |                                                                                   |
| float32   | 0 is encoded as a single byte `0x00`. <br> Otherwise: marker `0xf0` followed by 4 bytes (IEEE 754, little endian).                                                                                                                                                                           | <div>0.0 -> 0x00</div> <div>1.5 -> 0xf0 00 00 c0 3f</div>                         |
| float64   | 0 is encoded as a single byte `0x00`. <br> Otherwise: marker `0xf1` followed by 8 bytes (IEEE 754, little endian).                                                                                                                                                                           | <div>0.0 -> 0x00</div>                                                            |
| timestamp | 0 (Epoch) is encoded as a single byte `0x00`. <br> Otherwise: marker `0xef` followed by 8 bytes (int64 millis).                                                                                                                                                                              |                                                                                   |
| string    | Empty string: `0xf2`. <br> Non-empty: marker `0xf3`, followed by length (encoded as a number), followed by UTF-8 bytes.                                                                                                                                                                      | "Hi" -> 0xf3 0x02 0x48 0x69                                                       |
| bytes     | Empty: `0xf4`. <br> Non-empty: marker `0xf5`, followed by length (encoded as a number), followed by raw bytes.                                                                                                                                                                               |                                                                                   |
| T?        | `null` is encoded as `0xff`. <br>Otherwise, the value is encoded directly.                                                                                                                                                                                                                   | <div>null -> 0xff</div> <div>val -> val_bytes</div>                               |
| [T]       | Length 0-3: markers `0xf6`-`0xf9`. <br> Length > 3: marker `0xfa` followed by length (encoded as a number). <br>Then items are written sequentially.                                                                                                                                         | [1, 2] -> 0xf8 ... ...                                                            |
| struct    | Same encoding as an array. The array index corresponds to the field number. Removed fields are represented as `0`. Trailing default values are omitted.                                                                                                                                      |                                                                                   |
| enum      | Constant variant: encoded as a number (the variant number).<br> Wrapper variant: markers `0xfb`-`0xfe` (for variant numbers 1-4) or `0xf8` followed by the variant number. Then the value.                                                                                                   |                                                                                   |

## Deserialization

### JSON flavors

When Skir _deserializes_ JSON, it knows how to handle both dense and readable flavor. You do not need to specify which flavor is being used.

### Handling of zeros

Both the dense JSON and binary formats use zeros to represent `removed` fields to save space. To preserve forward compatibility, _zero_ is treated as a valid input for any type, even non-numerical ones.

With the exception of optional types (`T?`), all types will decode a _zero_ value (integer 0) as the default value for that type. For example, a `string` decodes 0 as `""`, and an array decodes 0 as `[]`. For optional types, 0 is decoded as the default value of the underlying type (e.g. `string?` decodes 0 as `""`, not `null`).

## Converter web app

Skir provides a hosted converter at [skir.build/converter](/converter.html) to convert values across dense JSON, readable JSON, and binary. You can also reach it at any time by clicking **Converter** in the header of this website. All processing happens locally in your browser — no data ever leaves your machine.

### Provide a schema

The converter needs a schema, which you can provide in two ways:

- A type descriptor JSON from generated code. In Python, for example, you can get it from `User.serializer.type_descriptor.as_json_code()`. The syntax is similar in other languages. A common pattern is to store the type descriptor JSON as metadata next to your serialized data, so it is always at hand when you need to inspect a value.
- A GitHub URL pointing to a specific line where a record is defined in a `.skir` file, for example [`https://github.com/gepheum/skir-fantasy-game-example/blob/v1.0.0/skir-src/fantasy_game.skir#L123`](https://github.com/gepheum/skir-fantasy-game-example/blob/v1.0.0/skir-src/fantasy_game.skir#L123) .

### Paste a value

Once the schema is loaded, paste the value you want to inspect. The converter accepts dense JSON, readable JSON, and binary (base16 or base64) — it detects the format automatically. It then shows the value converted to all three formats.

### Demo: schema from GitHub

<HoverVideo src="/skir-converter-github.mp4" />

### Demo: schema from type descriptor JSON

<HoverVideo src="/skir-converter-type-descriptor.mp4" />
