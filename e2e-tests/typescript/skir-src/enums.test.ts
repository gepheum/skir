import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { EnumVariant } from "skir-client";
import { SerializerTester } from "../../node_modules/skir-client/dist/esm/serializer_tester.js";
import { JsonValue, Weekday } from "../skirout/enums.js";
import { Car } from "../skirout/vehicles/car.js";

describe("simple enum", () => {
  const monday = Weekday.MONDAY;

  describe("#create", () => {
    it("unknown field", () => {
      JsonValue.create({ kind: "boolean", value: true });
      expect(Weekday.create("UNKNOWN")).toBe(Weekday.UNKNOWN);
    });

    it("constant name", () => {
      expect(Weekday.create("MONDAY")).toBe(monday);
    });

    it("constant", () => {
      expect(Weekday.create(monday)).toBe(monday);
    });
  });

  describe("#kind", () => {
    it("constant", () => {
      expect(monday.union.kind).toBe("MONDAY");
    });
    it("#UNKNOWN", () => {
      expect(Weekday.UNKNOWN.union.kind).toBe("UNKNOWN");
    });
  });

  describe("#typeDescriptor", () => {
    it("#kind", () => {
      expect(Weekday.serializer.typeDescriptor.kind).toBe("enum");
    });

    it("#asJson()", () => {
      expect(JsonValue.serializer.typeDescriptor.asJson()).toMatch({
        type: {
          kind: "record",
          value: "enums.skir:JsonValue",
        },
        records: [
          {
            kind: "enum",
            id: "enums.skir:JsonValue",
            variants: [
              {
                name: "null",
                number: 1,
              },
              {
                name: "boolean",
                number: 100,
                type: {
                  kind: "primitive",
                  value: "bool",
                },
              },
              {
                name: "number",
                number: 6,
                type: {
                  kind: "primitive",
                  value: "float64",
                },
              },
              {
                name: "string",
                number: 3,
                type: {
                  kind: "primitive",
                  value: "string",
                },
              },
              {
                name: "array",
                number: 4,
                type: {
                  kind: "array",
                  value: {
                    item: {
                      kind: "record",
                      value: "enums.skir:JsonValue",
                    },
                  },
                },
              },
              {
                name: "object",
                number: 5,
                type: {
                  kind: "array",
                  value: {
                    item: {
                      kind: "record",
                      value: "enums.skir:JsonValue.Pair",
                    },
                  },
                },
              },
            ],
          },
          {
            kind: "struct",
            id: "enums.skir:JsonValue.Pair",
            fields: [
              {
                name: "name",
                type: {
                  kind: "primitive",
                  value: "string",
                },
                number: 0,
              },
              {
                name: "value",
                type: {
                  kind: "record",
                  value: "enums.skir:JsonValue",
                },
                number: 1,
              },
            ],
          },
        ],
      });
      expect(JsonValue.Pair.serializer.typeDescriptor.asJson()).toMatch({
        type: {
          kind: "record",
          value: "enums.skir:JsonValue.Pair",
        },
      });
      new SerializerTester(
        JsonValue.serializer,
      ).reserializeTypeAdapterAndAssertNoLoss();
    });
  });

  describe("serializer", () => {
    const serializerTester = new SerializerTester(Weekday.serializer);
    serializerTester.reserializeAndAssert(Weekday.UNKNOWN, {
      denseJson: 0,
      readableJson: "unknown",
      bytesAsBase16: "00",
    });
    serializerTester.reserializeAndAssert(monday, {
      denseJson: 1,
      readableJson: "monday",
      bytesAsBase16: "01",
    });
    serializerTester.reserializeAndAssert(Weekday.TUESDAY, {
      denseJson: 2,
      readableJson: "tuesday",
      bytesAsBase16: "02",
    });
  });

  describe("#toString", () => {
    expect(Weekday.SATURDAY.toString()).toBe('"saturday"');
  });

  {
    const _: Weekday.Kind = "MONDAY";
  }
  {
    const _: Weekday.Kind = "UNKNOWN";
  }
});

describe("recursive enum", () => {
  describe("#from", () => {
    it("constant name", () => {
      expect(JsonValue.create("NULL")).toBe(JsonValue.NULL);
    });

    it("constant", () => {
      expect(JsonValue.create(JsonValue.NULL)).toBe(JsonValue.NULL);
    });
  });

  it("#create partial", () => {
    const partialValue = JsonValue.create<"partial">({
      kind: "object",
      value: [
        {
          name: "foo",
        },
      ],
    });
    expect(partialValue.union.kind).toBe("object");
  });

  const complexValue = JsonValue.create({
    kind: "array",
    value: [
      "NULL",
      {
        kind: "boolean",
        value: true,
      },
      JsonValue.NULL,
      {
        kind: "object",
        value: [
          {
            name: "foo",
            value: {
              kind: "string",
              value: "bar",
            },
          },
        ],
      },
    ],
  });

  const serializerTester = new SerializerTester(JsonValue.serializer);
  serializerTester.reserializeAndAssert(JsonValue.NULL, {
    denseJson: 1,
    readableJson: "null",
    bytesAsBase16: "01",
  });
  serializerTester.reserializeAndAssert(complexValue, {
    denseJson: [4, [1, [100, 1], 1, [5, [["foo", [3, "bar"]]]]]],
    readableJson: {
      kind: "array",
      value: [
        "null",
        {
          kind: "boolean",
          value: true,
        },
        "null",
        {
          kind: "object",
          value: [
            {
              name: "foo",
              value: {
                kind: "string",
                value: "bar",
              },
            },
          ],
        },
      ],
    },
    bytesAsBase16: "fefa0401f8640101f805f7f8f303666f6ffdf303626172",
  });

  it("#kind", () => {
    expect(complexValue.union.kind).toBe("array");
  });

  it("#value", () => {
    expect(Array.isArray(complexValue.union.value)).toBe(true);
  });

  it("#union", () => {
    expect(complexValue.union).toBe(
      complexValue as unknown as JsonValue.UnionView,
    );
  });

  it("switch", () => {
    const arrayLength = (() => {
      switch (complexValue.union.kind) {
        case "UNKNOWN":
          return -1;
        case "array":
          return complexValue.union.value.length;
        default:
          return 0;
      }
    })();
    expect(arrayLength).toBe(4);
  });

  it("#toString", () => {
    expect(complexValue.toString()).toBe(
      [
        "{",
        '  "kind": "array",',
        '  "value": [',
        '    "null",',
        "    {",
        '      "kind": "boolean",',
        '      "value": true',
        "    },",
        '    "null",',
        "    {",
        '      "kind": "object",',
        '      "value": [',
        "        {",
        '          "name": "foo",',
        '          "value": {',
        '            "kind": "string",',
        '            "value": "bar"',
        "          }",
        "        }",
        "      ]",
        "    }",
        "  ]",
        "}",
      ].join("\n"),
    );
  });

  {
    const _: JsonValue.Kind = "NULL";
  }
  {
    const _: JsonValue.Kind = "array";
  }
});

describe("enum reflection", () => {
  it("get module path", () => {
    expect(Car.serializer.typeDescriptor.modulePath).toBe("vehicles/car.skir");
  });

  describe("get record name", () => {
    it("#0", () => {
      expect(JsonValue.serializer.typeDescriptor.name).toBe("JsonValue");
    });
    it("#1", () => {
      expect(JsonValue.serializer.typeDescriptor.qualifiedName).toBe(
        "JsonValue",
      );
    });
    it("#2", () => {
      expect(JsonValue.Pair.serializer.typeDescriptor.name).toBe("Pair");
    });
    it("#3", () => {
      expect(JsonValue.Pair.serializer.typeDescriptor.qualifiedName).toBe(
        "JsonValue.Pair",
      );
    });
  });

  describe("get parent type", () => {
    it("#0", () => {
      expect(JsonValue.Pair.serializer.typeDescriptor.parentType).toBe(
        JsonValue.serializer.typeDescriptor,
      );
    });
    it("#1", () => {
      expect(JsonValue.serializer.typeDescriptor.parentType).toBe(undefined);
    });
  });

  describe("get field", () => {
    const typeDescriptor = JsonValue.serializer.typeDescriptor;
    it("#0", () => {
      expect(typeDescriptor.kind).toBe("enum");
    });

    const nullField: EnumVariant<JsonValue> = typeDescriptor.getVariant("NULL");
    const arrayField: EnumVariant<JsonValue> =
      typeDescriptor.getVariant("array");
    const unknownField: EnumVariant<JsonValue> =
      typeDescriptor.getVariant("UNKNOWN");

    it("#1", () => {
      expect(nullField).toBe(typeDescriptor.getVariant(1)!);
    });
    it("#2", () => {
      expect(arrayField).toBe(typeDescriptor.getVariant(4)!);
    });
    it("#3", () => {
      expect(unknownField).toBe(typeDescriptor.getVariant(0)!);
    });

    it("#4", () => {
      expect(nullField.name).toBe("NULL");
    });
    it("#5", () => {
      expect(nullField.number).toBe(1);
    });
    it("#6", () => {
      expect(arrayField.name).toBe("array");
    });
    it("#7", () => {
      expect(arrayField.number).toBe(4);
    });
    it("#8", () => {
      expect(unknownField.name).toBe("UNKNOWN");
    });
    it("#9", () => {
      expect(unknownField.number).toBe(0);
    });

    const arrayType = arrayField.type!;
    it("#10", () => {
      expect(arrayType.kind).toBe("array");
    });
    if (arrayType.kind === "array") {
      it("#11", () => {
        expect(arrayType.itemType.kind).toBe("enum");
      });
    }

    it("#12", () => {
      expect(typeDescriptor.getVariant("foo")).toBe(undefined);
    });
    it("#13", () => {
      expect(typeDescriptor.getVariant(10)).toBe(undefined);
    });

    // Let's make sure that the return type is nullable.
    {
      const absentField = typeDescriptor.getVariant("foo");
      const _: undefined extends typeof absentField ? true : never = true;
    }
    {
      const absentField = typeDescriptor.getVariant(10);
      const _: undefined extends typeof absentField ? true : never = true;
    }
  });
});
