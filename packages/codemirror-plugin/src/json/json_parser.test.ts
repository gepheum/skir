import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { parseJsonValue } from "./json_parser.js";

describe("json_parser", () => {
  it("parses true", () => {
    expect(parseJsonValue("true")).toMatch({
      value: {
        kind: "literal",
        jsonCode: "true",
        type: "boolean",
      },
      errors: [],
      edits: [],
    });
  });

  it("parses false", () => {
    expect(parseJsonValue("false")).toMatch({
      value: {
        kind: "literal",
        jsonCode: "false",
        type: "boolean",
      },
      errors: [],
      edits: [],
    });
  });

  it("parses null", () => {
    expect(parseJsonValue("null")).toMatch({
      value: {
        kind: "literal",
        jsonCode: "null",
        type: "null",
      },
      errors: [],
      edits: [],
    });
  });

  it("parses number", () => {
    expect(parseJsonValue("123.45")).toMatch({
      value: {
        kind: "literal",
        jsonCode: "123.45",
        type: "number",
      },
      errors: [],
      edits: [],
    });
  });

  it("parses string", () => {
    expect(parseJsonValue('"hello"')).toMatch({
      value: {
        kind: "literal",
        jsonCode: '"hello"',
        type: "string",
      },
      errors: [],
      edits: [],
    });
  });

  it("tracks indent for top-level literal", () => {
    expect(parseJsonValue("   true")).toMatch({
      value: {
        kind: "literal",
        jsonCode: "true",
        type: "boolean",
        indent: 3,
      },
      errors: [],
    });
  });

  it("parses empty array", () => {
    expect(parseJsonValue("[]")).toMatch({
      value: { kind: "array", values: [] },
      errors: [],
      edits: [],
    });
  });

  it("parses array with values", () => {
    expect(parseJsonValue("[1, true]")).toMatch({
      value: {
        kind: "array",
        values: [
          { kind: "literal", jsonCode: "1", type: "number" },
          { kind: "literal", jsonCode: "true", type: "boolean" },
        ],
      },
      errors: [],
      edits: [
        { segment: { start: 1, end: 1 }, replacement: "\n  " },
        { segment: { start: 3, end: 4 }, replacement: "\n  " },
        { segment: { start: 8, end: 8 }, replacement: "\n" },
      ],
    });
  });

  it("parses empty object", () => {
    expect(parseJsonValue("{}")).toMatch({
      value: {
        kind: "object",
        keyValues: {},
      },
      errors: [],
      edits: [],
    });
  });

  it("parses object with values", () => {
    expect(parseJsonValue('{"a": 1}')).toMatch({
      value: {
        kind: "object",
        keyValues: {
          a: {
            key: "a",
            value: { kind: "literal", jsonCode: "1", type: "number" },
          },
        },
      },
      errors: [],
      edits: [
        { segment: { start: 1, end: 1 }, replacement: "\n  " },
        { segment: { start: 7, end: 7 }, replacement: "\n" },
      ],
    });
  });

  it("tracks indent from line leading spaces for field values", () => {
    const result = parseJsonValue(`{
  "a": 1,
  "b": [
    2
  ]
}`);

    expect(result).toMatch({
      value: {
        kind: "object",
        indent: 0,
        keyValues: {
          a: {
            value: {
              kind: "literal",
              jsonCode: "1",
              indent: 2,
            },
          },
          b: {
            value: {
              kind: "array",
              indent: 2,
              values: [
                {
                  kind: "literal",
                  jsonCode: "2",
                  indent: 4,
                },
              ],
            },
          },
        },
      },
      errors: [],
    });
  });

  it("parses arrays with whitespace", () => {
    expect(parseJsonValue(" [ 1 ] ")).toMatch({
      value: {
        kind: "array",
        values: [{ kind: "literal", jsonCode: "1" }],
      },
      errors: [],
      edits: [
        { segment: { start: 0, end: 1 }, replacement: "" },
        { segment: { start: 2, end: 3 }, replacement: "\n  " },
        { segment: { start: 4, end: 5 }, replacement: "\n" },
        { segment: { start: 6, end: 7 }, replacement: "" },
      ],
    });
  });

  it("reports error for invalid token", () => {
    expect(parseJsonValue("@")).toMatch({
      value: undefined,
      errors: [
        {
          kind: "error",
          message: "not a token",
          segment: { start: 0, end: 1 },
        },
      ],
      edits: [],
    });
  });

  it("reports error for unclosed array", () => {
    expect(parseJsonValue("[")).toMatch({
      value: { kind: "array", values: [] },
      errors: [
        {
          kind: "error",
          message: "expected: ']'",
          segment: { start: 1, end: 1 },
        },
      ],
      edits: [{ segment: { start: 1, end: 1 }, replacement: "\n  " }],
    });
  });

  it("parses object with missing value (lenient)", () => {
    expect(
      parseJsonValue(`{
      "foo": true,
      "bar"
    }`),
    ).toMatch({
      value: {
        kind: "object",
        keyValues: {
          foo: {
            key: "foo",
            value: { kind: "literal", jsonCode: "true", type: "boolean" },
          },
        },
      },
      errors: [
        {
          kind: "error",
          message: "expected: ':'",
          segment: { start: 37, end: 38 },
        },
      ],
    });
  });

  it("parses object with trailing comma (lenient)", () => {
    expect(
      parseJsonValue(`{
      "a": 1,
      "b": 2,
    }`),
    ).toMatch({
      value: {
        kind: "object",
        keyValues: {
          a: {
            key: "a",
            value: { kind: "literal", jsonCode: "1", type: "number" },
          },
          b: {
            key: "b",
            value: { kind: "literal", jsonCode: "2", type: "number" },
          },
        },
      },
      errors: [],
      edits: [
        { segment: { start: 1, end: 8 }, replacement: "\n  " },
        { segment: { start: 15, end: 22 }, replacement: "\n  " },
        { segment: { start: 28, end: 29 }, replacement: "" },
        { segment: { start: 29, end: 34 }, replacement: "\n" },
      ],
    });
  });

  it("parses array with trailing comma (lenient)", () => {
    expect(parseJsonValue(`[1, 2,]`)).toMatch({
      value: {
        kind: "array",
        values: [
          { kind: "literal", jsonCode: "1", type: "number" },
          { kind: "literal", jsonCode: "2", type: "number" },
        ],
      },
      errors: [],
      edits: [
        { segment: { start: 1, end: 1 }, replacement: "\n  " },
        { segment: { start: 3, end: 4 }, replacement: "\n  " },
        { segment: { start: 5, end: 6 }, replacement: "" },
        { segment: { start: 6, end: 6 }, replacement: "\n" },
      ],
    });
  });

  it("parses array without commas (adds commas via edits)", () => {
    expect(parseJsonValue("[1 2 3]")).toMatch({
      value: {
        kind: "array",
        values: [
          { kind: "literal", jsonCode: "1", type: "number" },
          { kind: "literal", jsonCode: "2", type: "number" },
          { kind: "literal", jsonCode: "3", type: "number" },
        ],
      },
      errors: [],
      edits: [
        { segment: { start: 1, end: 1 }, replacement: "\n  " },
        { segment: { start: 2, end: 3 }, replacement: ",\n  " },
        { segment: { start: 4, end: 5 }, replacement: ",\n  " },
        { segment: { start: 6, end: 6 }, replacement: "\n" },
      ],
    });
  });

  it("parses object without commas (adds commas via edits)", () => {
    expect(parseJsonValue('{"a": 1 "b": 2}')).toMatch({
      value: {
        kind: "object",
        keyValues: {
          a: {
            key: "a",
            value: { kind: "literal", jsonCode: "1", type: "number" },
          },
          b: {
            key: "b",
            value: { kind: "literal", jsonCode: "2", type: "number" },
          },
        },
      },
      errors: [],
      edits: [
        { segment: { start: 1, end: 1 }, replacement: "\n  " },
        { segment: { start: 7, end: 8 }, replacement: ",\n  " },
        { segment: { start: 14, end: 14 }, replacement: "\n" },
      ],
    });
  });

  it("parses object with key missing colon (no infinite loop)", () => {
    const result = parseJsonValue(`
      {
        "x": 0,
        ""
        "y": 0
      }`);
    // Should parse without hanging
    // Note: The empty key without colon causes skip() to consume "y": 0
    expect(result).toMatch({
      value: {
        kind: "object",
        keyValues: {
          x: {
            key: "x",
            value: { kind: "literal", jsonCode: "0", type: "number" },
          },
        },
        allKeys: [
          {
            key: "x",
          },
          {
            key: "",
          },
          {
            key: "y",
          },
        ],
      },
      errors: [
        {
          kind: "error",
          message: "expected: ':'",
        },
      ],
    });
  });

  it("parses object with double comma (no infinite loop)", () => {
    const result = parseJsonValue('{"x": 1, , "y": 2}');
    // Should parse without hanging - the double comma should be handled
    expect(result.value).toMatch({
      kind: "object",
      keyValues: {
        x: {
          key: "x",
          value: { kind: "literal", jsonCode: "1", type: "number" },
        },
        y: {
          key: "y",
          value: { kind: "literal", jsonCode: "2", type: "number" },
        },
      },
    });
    // Should have error for the unexpected comma
    expect(result.errors.length > 0).toBe(true);
  });

  it("parses array with invalid element followed by comma (no infinite loop)", () => {
    const result = parseJsonValue(`[
  1,
  @
  2
]`);
    // Invalid token @ causes tokenization error
    expect(result.value).toBe(undefined);
    // Should have error for invalid token
    expect(result.errors).toMatch([
      {
        kind: "error",
        message: "not a token",
      },
    ]);
  });
});
