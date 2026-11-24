import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { parseJsonValue } from "./json_parser.js";
import { validateSchema } from "./schema_validator.js";
import { JsonValue, TypeDefinition } from "./types.js";

function parse(json: string): JsonValue {
  const result = parseJsonValue(json);
  if (!result.value) {
    throw new Error(`JSON parse error: ${JSON.stringify(result.errors)}`);
  }
  return result.value;
}

describe("schema_validator", () => {
  it("validates primitive int32", () => {
    const schema: TypeDefinition = {
      type: { kind: "primitive", value: "int32" },
      records: [],
    };
    const result = validateSchema(parse("123"), schema);
    expect(result).toMatch({ errors: [] });
    if (result.hints.length === 0) {
      throw new Error("Expected type hints");
    }
  });

  it("validates primitive string", () => {
    const schema: TypeDefinition = {
      type: { kind: "primitive", value: "string" },
      records: [],
    };
    const result = validateSchema(parse('"hello"'), schema);
    expect(result).toMatch({ errors: [] });
  });

  it("reports error for type mismatch (int32 vs string)", () => {
    const schema: TypeDefinition = {
      type: { kind: "primitive", value: "int32" },
      records: [],
    };
    const result = validateSchema(parse('"hello"'), schema);
    expect(result.errors).toMatch([
      {
        message: "Expected: int32",
      },
    ]);
  });

  it("validates array of primitives", () => {
    const schema: TypeDefinition = {
      type: {
        kind: "array",
        value: { item: { kind: "primitive", value: "int32" } },
      },
      records: [],
    };
    const result = validateSchema(parse("[1, 2, 3]"), schema);
    expect(result).toMatch({ errors: [] });
  });

  it("reports error for invalid array item", () => {
    const schema: TypeDefinition = {
      type: {
        kind: "array",
        value: { item: { kind: "primitive", value: "int32" } },
      },
      records: [],
    };
    const result = validateSchema(parse('[1, "bad", 3]'), schema);
    expect(result.errors).toMatch([
      {
        message: "Expected: int32",
        segment: {
          start: 4,
          end: 9,
        },
      },
    ]);
  });

  it("validates optional field (present)", () => {
    const schema: TypeDefinition = {
      type: {
        kind: "optional",
        value: { kind: "primitive", value: "int32" },
      },
      records: [],
    };
    const result = validateSchema(parse("123"), schema);
    expect(result).toMatch({ errors: [] });
  });

  it("validates optional field (null)", () => {
    const schema: TypeDefinition = {
      type: {
        kind: "optional",
        value: { kind: "primitive", value: "int32" },
      },
      records: [],
    };
    const result = validateSchema(parse("null"), schema);
    expect(result).toMatch({ errors: [] });
  });

  it("validates struct", () => {
    const schema: TypeDefinition = {
      type: { kind: "record", value: "MyStruct" },
      records: [
        {
          kind: "struct",
          id: "MyStruct",
          fields: [
            {
              name: "foo",
              number: 1,
              type: { kind: "primitive", value: "string" },
            },
            {
              name: "bar",
              number: 2,
              type: { kind: "primitive", value: "int32" },
            },
          ],
        },
      ],
    };
    const result = validateSchema(parse('{"foo": "hi", "bar": 123}'), schema);
    expect(result).toMatch({ errors: [] });
  });

  it("reports unknown field in struct", () => {
    const schema: TypeDefinition = {
      type: { kind: "record", value: "MyStruct" },
      records: [
        {
          kind: "struct",
          id: "MyStruct",
          fields: [],
        },
      ],
    };
    const result = validateSchema(parse('{"unknown": 1}'), schema);
    expect(result.errors).toMatch([
      {
        message: "Unknown field",
        segment: {
          start: 1,
          end: 10,
        },
      },
    ]);
  });

  it("validates enum (string literal accepts lower and upper)", () => {
    const schema: TypeDefinition = {
      type: { kind: "record", value: "MyEnum" },
      records: [
        {
          kind: "enum",
          id: "MyEnum",
          variants: [
            { name: "FOO", number: 1 },
            { name: "BAR", number: 2 },
          ],
        },
      ],
    };
    const lowerResult = validateSchema(parse('"foo"'), schema);
    expect(lowerResult).toMatch({ errors: [] });

    const upperResult = validateSchema(parse('"FOO"'), schema);
    expect(upperResult).toMatch({ errors: [] });
  });

  it("rejects mixed-case enum string literal", () => {
    const schema: TypeDefinition = {
      type: { kind: "record", value: "MyEnum" },
      records: [
        {
          kind: "enum",
          id: "MyEnum",
          variants: [{ name: "FOO", number: 1 }],
        },
      ],
    };

    const result = validateSchema(parse('"Foo"'), schema);
    expect(result.errors).toMatch([
      {
        message: "Unknown variant",
      },
    ]);
  });

  it("accepts UNKNOWN and unknown enum literals", () => {
    const schema: TypeDefinition = {
      type: { kind: "record", value: "MyEnum" },
      records: [
        {
          kind: "enum",
          id: "MyEnum",
          variants: [{ name: "FOO", number: 1 }],
        },
      ],
    };

    expect(validateSchema(parse('"UNKNOWN"'), schema)).toMatch({ errors: [] });
    expect(validateSchema(parse('"unknown"'), schema)).toMatch({ errors: [] });

    const mixedCaseResult = validateSchema(parse('"Unknown"'), schema);
    expect(mixedCaseResult.errors).toMatch([
      {
        message: "Unknown variant",
      },
    ]);
  });

  it("validates enum object kind in lower and upper", () => {
    const schema: TypeDefinition = {
      type: { kind: "record", value: "MyEnum" },
      records: [
        {
          kind: "enum",
          id: "MyEnum",
          variants: [
            {
              name: "COMPLEX",
              number: 1,
              type: { kind: "primitive", value: "int32" },
            },
          ],
        },
      ],
    };

    expect(
      validateSchema(parse('{"kind": "complex", "value": 123}'), schema),
    ).toMatch({
      errors: [],
    });
    expect(
      validateSchema(parse('{"kind": "COMPLEX", "value": 123}'), schema),
    ).toMatch({
      errors: [],
    });

    const mixedCaseResult = validateSchema(
      parse('{"kind": "Complex", "value": 123}'),
      schema,
    );
    expect(mixedCaseResult.errors).toMatch([
      {
        message: "Unknown variant",
      },
    ]);
  });

  it("reports unknown enum variant", () => {
    const schema: TypeDefinition = {
      type: { kind: "record", value: "MyEnum" },
      records: [
        {
          kind: "enum",
          id: "MyEnum",
          variants: [{ name: "First", number: 1 }],
        },
      ],
    };
    const result = validateSchema(parse('"Unknown"'), schema);
    expect(result.errors).toMatch([
      {
        message: "Unknown variant",
      },
    ]);
  });

  it("reports error when typed enum variant is provided as string", () => {
    const schema: TypeDefinition = {
      type: { kind: "record", value: "MyEnum" },
      records: [
        {
          kind: "enum",
          id: "MyEnum",
          variants: [
            {
              name: "COMPLEX",
              number: 1,
              type: { kind: "primitive", value: "int32" },
            },
          ],
        },
      ],
    };

    const result = validateSchema(parse('"COMPLEX"'), schema);
    expect(result.errors).toMatch([
      {
        message: "Expected: constant variant",
      },
    ]);
  });

  it("reports error when constant enum variant is provided as object", () => {
    const schema: TypeDefinition = {
      type: { kind: "record", value: "MyEnum" },
      records: [
        {
          kind: "enum",
          id: "MyEnum",
          variants: [{ name: "SIMPLE", number: 1 }],
        },
      ],
    };

    const result = validateSchema(parse('{"kind": "SIMPLE"}'), schema);
    expect(result.errors).toMatch([
      {
        message: "Expected: wrapper variant",
      },
      {
        message: "Missing: 'value'",
      },
    ]);
  });

  it("stores enum definition in type hint for UNKNOWN enum literal", () => {
    const schema: TypeDefinition = {
      type: { kind: "record", value: "MyEnum" },
      records: [
        {
          kind: "enum",
          id: "MyEnum",
          variants: [
            { name: "First", number: 1 },
            { name: "Second", number: 2 },
          ],
        },
      ],
    };

    const result = validateSchema(parse('"UNKNOWN"'), schema);
    expect(result.errors).toMatch([]);
    if (!result.rootTypeHint) {
      throw new Error("Expected root type hint");
    }
    expect(result.rootTypeHint.enumDefinition).toMatch({
      kind: "enum",
      id: "MyEnum",
      variants: [
        { name: "First", number: 1 },
        { name: "Second", number: 2 },
      ],
    });
  });

  it("stores enum definition in nested UNKNOWN enum field hint", () => {
    const schema: TypeDefinition = {
      type: { kind: "record", value: "MyStruct" },
      records: [
        {
          kind: "struct",
          id: "MyStruct",
          fields: [
            {
              name: "status",
              number: 1,
              type: { kind: "record", value: "MyEnum" },
            },
          ],
        },
        {
          kind: "enum",
          id: "MyEnum",
          variants: [
            { name: "First", number: 1 },
            { name: "Second", number: 2 },
          ],
        },
      ],
    };

    const result = validateSchema(parse('{"status": "UNKNOWN"}'), schema);
    expect(result.errors).toMatch([]);
    if (!result.rootTypeHint) {
      throw new Error("Expected root type hint");
    }
    if (result.rootTypeHint.childHints.length !== 1) {
      throw new Error("Expected one child type hint");
    }
    const statusHint = result.rootTypeHint.childHints[0];
    expect(statusHint.enumDefinition).toMatch({
      kind: "enum",
      id: "MyEnum",
      variants: [
        { name: "First", number: 1 },
        { name: "Second", number: 2 },
      ],
    });
  });

  it("validates enum (object with kind)", () => {
    const schema: TypeDefinition = {
      type: { kind: "record", value: "MyEnum" },
      records: [
        {
          kind: "enum",
          id: "MyEnum",
          variants: [
            {
              name: "complex",
              number: 1,
              type: { kind: "primitive", value: "int32" },
            },
          ],
        },
      ],
    };

    expect(
      validateSchema(parse('{"kind": "complex", "value": 123}'), schema),
    ).toMatch({ errors: [] });
    expect(
      validateSchema(parse('{"kind": "complex", "value": "foo"}'), schema),
    ).toMatch({
      errors: [
        {
          message: "Expected: int32",
        },
      ],
    });
    expect(validateSchema(parse('{"kind": "complex"}'), schema)).toMatch({
      errors: [
        {
          message: "Missing: 'value'",
        },
      ],
    });
  });
});
