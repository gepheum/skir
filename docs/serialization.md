## Serialization formats

When serializing a data structure, you can chose one of 3 formats.

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

const JOHN_DOE = {
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
