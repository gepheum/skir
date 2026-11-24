import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { parseJsonValue } from "./json_parser.js";
import { makeJsonTemplate, toJson } from "./to_json.js";
import { JsonValue, RecordDefinition, TypeSignature } from "./types.js";

function parse(json: string): JsonValue {
  const result = parseJsonValue(json);
  if (!result.value) {
    throw new Error(`JSON parse error: ${JSON.stringify(result.errors)}`);
  }
  return result.value;
}

describe("to_json", () => {
  describe("toJson", () => {
    it("converts primitives", () => {
      expect(toJson(parse("true"))).toBe(true);
      expect(toJson(parse("false"))).toBe(false);
      expect(toJson(parse("null"))).toBe(null);
      expect(toJson(parse("123"))).toBe(123);
      expect(toJson(parse('"hello"'))).toBe("hello");
    });

    it("converts array", () => {
      expect(toJson(parse("[1, 2, 3]"))).toMatch([1, 2, 3]);
    });

    it("converts object", () => {
      expect(toJson(parse('{"a": 1, "b": "2"}'))).toMatch({ a: 1, b: "2" });
    });

    it("converts nested structure", () => {
      const input = '{"arr": [1, {"x": "y"}], "obj": {"z": null}}';
      expect(toJson(parse(input))).toMatch({
        arr: [1, { x: "y" }],
        obj: { z: null },
      });
    });
  });

  describe("makeJsonTemplate", () => {
    const emptyRecords: { [id: string]: RecordDefinition } = {};

    it("creates template for array", () => {
      const type: TypeSignature = {
        kind: "array",
        value: { item: { kind: "primitive", value: "int32" } },
      };
      expect(makeJsonTemplate(type, emptyRecords)).toMatch([]);
    });

    it("creates template for optional", () => {
      const type: TypeSignature = {
        kind: "optional",
        value: { kind: "primitive", value: "int32" },
      };
      expect(makeJsonTemplate(type, emptyRecords)).toBe(null);
    });

    it("creates template for primitives", () => {
      expect(
        makeJsonTemplate({ kind: "primitive", value: "bool" }, emptyRecords),
      ).toBe(false);
      expect(
        makeJsonTemplate({ kind: "primitive", value: "int32" }, emptyRecords),
      ).toBe(0);
      expect(
        makeJsonTemplate({ kind: "primitive", value: "float64" }, emptyRecords),
      ).toBe(0);
      expect(
        makeJsonTemplate({ kind: "primitive", value: "int64" }, emptyRecords),
      ).toBe("0");
      expect(
        makeJsonTemplate({ kind: "primitive", value: "string" }, emptyRecords),
      ).toBe("");
    });

    it("creates template for struct", () => {
      const records: { [id: string]: RecordDefinition } = {
        MyStruct: {
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
      };
      const type: TypeSignature = { kind: "record", value: "MyStruct" };
      expect(makeJsonTemplate(type, records)).toMatch({
        foo: "",
        bar: 0,
      });
    });

    it("creates template for nested struct (depth limit)", () => {
      const records: { [id: string]: RecordDefinition } = {
        Parent: {
          kind: "struct",
          id: "Parent",
          fields: [
            {
              name: "child",
              number: 1,
              type: { kind: "record", value: "Child" },
            },
          ],
        },
        Child: {
          kind: "struct",
          id: "Child",
          fields: [
            {
              name: "val",
              number: 1,
              type: { kind: "primitive", value: "int32" },
            },
          ],
        },
      };
      const type: TypeSignature = { kind: "record", value: "Parent" };
      // Expect child to be {}, because depth logic in makeJsonTemplate
      // passes "depth" to recursive call for struct fields.
      expect(makeJsonTemplate(type, records)).toMatch({
        child: {},
      });
    });

    it("creates template for enum", () => {
      const records: { [id: string]: RecordDefinition } = {
        MyEnum: {
          kind: "enum",
          id: "MyEnum",
          variants: [],
        },
      };
      const type: TypeSignature = { kind: "record", value: "MyEnum" };
      expect(makeJsonTemplate(type, records)).toBe("UNKNOWN");
    });
  });
});
