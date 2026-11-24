import { expect } from "buckwheat";
import { describe, it } from "mocha";
import assert from "node:assert/strict";
import * as skir from "../src/skir-client.js";
import {
  binary,
  structSerializer,
  type StructInstance,
} from "./test_helpers.js";

describe("complex nested types with enums", () => {
  it("can transform parsed type descriptor", () => {
    const typeDefinitionJson: skir.Json = {
      type: {
        kind: "record",
        value: "service.skir:CalculateMetricsRequest",
      },
      records: [
        {
          kind: "struct",
          id: "service.skir:CalculateMetricsRequest",
          doc: "Request to calculate basic metrics for a shape",
          fields: [
            {
              name: "shape",
              number: 0,
              type: {
                kind: "record",
                value: "geometry.skir:Shape",
              },
              doc: "The shape to analyze",
            },
            {
              name: "unit",
              number: 1,
              type: {
                kind: "record",
                value: "geometry.skir:MeasurementUnit",
              },
              doc: "Unit for the results",
            },
          ],
        },
        {
          kind: "enum",
          id: "geometry.skir:Shape",
          doc: "Geometric shape - demonstrates enum with wrapper variants",
          variants: [
            {
              name: "triangle",
              number: 1,
              doc: "A triangle defined by three vertices",
              type: {
                kind: "record",
                value: "geometry.skir:Shape.Triangle",
              },
            },
            {
              name: "circle",
              number: 2,
              doc: "A circle defined by center and radius",
              type: {
                kind: "record",
                value: "geometry.skir:Shape.Circle",
              },
            },
            {
              name: "rectangle",
              number: 3,
              doc: "A rectangle defined by top-left corner and dimensions",
              type: {
                kind: "record",
                value: "geometry.skir:Shape.Rectangle",
              },
            },
            {
              name: "polygon",
              number: 4,
              doc: "A general polygon defined by its vertices",
              type: {
                kind: "record",
                value: "geometry.skir:Shape.Polygon",
              },
            },
          ],
        },
        {
          kind: "struct",
          id: "geometry.skir:Shape.Triangle",
          fields: [
            {
              name: "vertices",
              number: 0,
              type: {
                kind: "array",
                value: {
                  item: {
                    kind: "record",
                    value: "geometry.skir:Point",
                  },
                },
              },
              doc: "The three corner points",
            },
          ],
        },
        {
          kind: "struct",
          id: "geometry.skir:Point",
          doc: "A point in 2D space",
          fields: [
            {
              name: "x",
              number: 0,
              type: {
                kind: "primitive",
                value: "float64",
              },
            },
            {
              name: "y",
              number: 1,
              type: {
                kind: "primitive",
                value: "float64",
              },
            },
          ],
        },
        {
          kind: "struct",
          id: "geometry.skir:Shape.Circle",
          fields: [
            {
              name: "center",
              number: 0,
              type: {
                kind: "record",
                value: "geometry.skir:Point",
              },
            },
            {
              name: "radius",
              number: 1,
              type: {
                kind: "primitive",
                value: "float64",
              },
            },
          ],
        },
        {
          kind: "struct",
          id: "geometry.skir:Shape.Rectangle",
          fields: [
            {
              name: "top_left",
              number: 0,
              type: {
                kind: "record",
                value: "geometry.skir:Point",
              },
            },
            {
              name: "width",
              number: 1,
              type: {
                kind: "primitive",
                value: "float64",
              },
            },
            {
              name: "height",
              number: 2,
              type: {
                kind: "primitive",
                value: "float64",
              },
            },
          ],
        },
        {
          kind: "struct",
          id: "geometry.skir:Shape.Polygon",
          fields: [
            {
              name: "vertices",
              number: 0,
              type: {
                kind: "array",
                value: {
                  item: {
                    kind: "record",
                    value: "geometry.skir:Point",
                  },
                },
              },
              doc: "Vertices in order (at least 3 required)",
            },
          ],
        },
        {
          kind: "enum",
          id: "geometry.skir:MeasurementUnit",
          doc: "Unit of measurement for distances and areas",
          variants: [
            {
              name: "METERS",
              number: 1,
              doc: "Metric system (meters, square meters)",
            },
            {
              name: "FEET",
              number: 2,
              doc: "Imperial system (feet, square feet)",
            },
            {
              name: "custom",
              number: 3,
              doc: "Custom unit with conversion factor to meters",
              type: {
                kind: "primitive",
                value: "float64",
              },
            },
          ],
        },
      ],
    };

    const typeDescriptor = skir.parseTypeDescriptorFromJson(typeDefinitionJson);

    // Test with empty array (default value)
    {
      const resultFromEmpty = typeDescriptor.transform([], "readable");
      expect(JSON.stringify(resultFromEmpty)).toMatch("{}");
    }
    {
      const resultFromEmpty = typeDescriptor.transform([], "dense");
      expect(JSON.stringify(resultFromEmpty)).toMatch("[]");
    }
    {
      const resultFromEmpty = typeDescriptor.transform([], "bytes");
      expect(skir.ByteString.sliceOf(resultFromEmpty).toBase16()).toMatch(
        "736b6972f6",
      );
    }

    // Test with default value in readable format
    const resultFromEmptyObj = typeDescriptor.transform({}, "dense");
    expect(JSON.stringify(resultFromEmptyObj)).toMatch("[]");

    // Test with actual data containing constant enum variant
    const denseWithConstant = [
      [2, [[], 5]], // shape: circle with center (0,0) and radius 5
      1, // unit: METERS (constant variant)
    ];
    const readableResult = typeDescriptor.transform(
      denseWithConstant,
      "readable",
    );
    expect(readableResult).toMatch({
      shape: {
        kind: "circle",
        value: {
          // center is omitted because it's default (x: 0, y: 0)
          radius: 5,
        },
      },
      unit: "meters",
    });

    // Test with wrapper enum variant
    const denseWithWrapper = [
      [2, [[1, 2], 5]], // shape: circle with center (1, 2) and radius 5
      [3, 2.5], // unit: custom variant with value 2.5
    ];
    const readableWithWrapper = typeDescriptor.transform(
      denseWithWrapper,
      "readable",
    );
    expect(readableWithWrapper).toMatch({
      shape: {
        kind: "circle",
        value: {
          center: {
            x: 1,
            y: 2,
          },
          radius: 5,
        },
      },
      unit: {
        kind: "custom",
        value: 2.5,
      },
    });

    // Test roundtrip: dense -> readable -> dense
    const roundtrip = typeDescriptor.transform(
      typeDescriptor.transform(denseWithWrapper, "readable"),
      "dense",
    );
    expect(roundtrip).toMatch(denseWithWrapper);
  });
});

describe("enum name case-compatibility", () => {
  const weekday = skir.parseTypeDescriptorFromJson({
    type: { kind: "record", value: "test.skir:Weekday" },
    records: [
      {
        kind: "enum",
        id: "test.skir:Weekday",
        variants: [
          { name: "monday", number: 1 },
          { name: "tuesday", number: 2 },
          {
            name: "custom",
            number: 3,
            type: { kind: "primitive", value: "string" },
          },
        ],
      },
    ],
  });

  it("serializes lowercase-named constant to lower_case readable JSON", () => {
    expect(weekday.transform(1, "readable")).toBe("monday");
  });

  it("parses UPPER_CASE constant name in readable JSON", () => {
    expect(weekday.transform("MONDAY", "dense")).toBe(1);
    expect(weekday.transform("monday", "dense")).toBe(1);
  });

  it("parses lower_case constant name in readable JSON", () => {
    expect(weekday.transform("tuesday", "dense")).toBe(2);
  });
});

describe("record serializers", () => {
  const keep = "keep-unrecognized-values";
  const emptyStruct = structSerializer({});
  const emptyEnum = skir.parseTypeDescriptorFromJson({
    type: { kind: "record", value: "test.skir:Record" },
    records: [{ kind: "enum", id: "test.skir:Record", variants: [] }],
  }) as unknown as skir.Serializer<StructInstance>;

  it("retains unknown struct objects without sharing mutable input", () => {
    const json = [{ nested: [1, { value: "kept" }] }];
    const value = emptyStruct.fromJson(json, keep);
    json[0]!.nested[1] = { value: "changed" };
    assert.deepEqual(emptyStruct.toJson(value), [
      { nested: [1, { value: "kept" }] },
    ]);
  });

  it("cross-format struct serialization leaves the original unknown payload intact", () => {
    const serializer = structSerializer({ known: "int32" });
    const json = [7, { nested: [9] }];
    const jsonValue = serializer.fromJson(json, keep);
    assert.deepEqual(serializer.toBytes(jsonValue).toBuffer(), binary(247, 7));
    assert.deepEqual(serializer.toJson(jsonValue, "readable"), { known: 7 });
    assert.deepEqual(serializer.toJson(jsonValue), json);
    const bytes = binary(248, 7, 9);
    const binaryValue = serializer.fromBytes(bytes, keep);
    assert.deepEqual(serializer.toJson(binaryValue), [7]);
    assert.deepEqual(serializer.toJson(binaryValue, "readable"), { known: 7 });
    assert.deepEqual(serializer.toBytes(binaryValue).toBuffer(), bytes);
  });

  it("rejects unknown readable fields when asked to keep them", () => {
    assert.throws(
      () => emptyStruct.fromJson({ future: 9 }, keep),
      /unrecognized/i,
    );
    assert.deepEqual(
      emptyStruct.toJson(emptyStruct.fromJson({ future: 9 })),
      [],
    );
  });

  it("retains unknown struct data through parsed descriptor transformations", () => {
    const descriptor = skir.parseTypeDescriptorFromJson({
      type: { kind: "record", value: "test.skir:Record" },
      records: [{ kind: "struct", id: "test.skir:Record", fields: [] }],
    });
    assert.deepEqual(descriptor.transform([9], "dense"), [9]);
    assert.deepEqual(
      descriptor.transform(binary(247, 9), "bytes"),
      binary(247, 9),
    );
    assert.deepEqual(descriptor.transform([9], "bytes"), binary(246));
    assert.deepEqual(descriptor.transform(binary(247, 9), "dense"), []);
  });

  for (const json of [
    9,
    500,
    [9, { nested: ["kept"] }],
    { kind: "future", value: [1] },
  ]) {
    it(`retains parsed enum JSON ${JSON.stringify(json)}`, () => {
      const value = emptyEnum.fromJson(json, keep);
      assert.deepEqual(emptyEnum.toJson(value), json);
      assert.deepEqual(emptyEnum.toBytes(value).toBuffer(), binary(0));
      assert.deepEqual(emptyEnum.toJson(value), json);
    });
  }

  for (const [kind, bytes] of [
    ["constant", binary(232, 244, 1)],
    ["wrapper", binary(251, 9)],
  ] as const) {
    it(`omits unknown binary enum ${kind} in JSON without losing it`, () => {
      const value = emptyEnum.fromBytes(bytes, keep);
      assert.equal(emptyEnum.toJson(value), 0);
      assert.equal(emptyEnum.toJson(value, "readable"), "unknown");
      assert.deepEqual(emptyEnum.toBytes(value).toBuffer(), bytes);
    });
  }

  it("rejects invalid struct and enum tags and enum variant numbers", () => {
    const serializers = [emptyStruct, emptyEnum];
    for (const serializer of serializers) {
      assert.throws(() => serializer.fromBytes(binary(244, 0)));
    }
    for (const keep of [undefined, "keep-unrecognized-values"] as const) {
      for (const payload of [
        [235, 255],
        [241, 0, 0, 0, 0, 0, 0, 248, 63],
        [248, 235, 255, 0],
        [248, 241, 0, 0, 0, 0, 0, 0, 248, 63, 0],
      ]) {
        assert.throws(() => emptyEnum.fromBytes(binary(...payload), keep));
      }
    }
  });

  for (const [kind, serializer, wire] of [
    ["struct", emptyStruct, 247],
    ["enum", emptyEnum, 251],
  ] as const) {
    it(`skips and retains BOMs and malformed UTF-8 nested in unknown ${kind} values`, () => {
      for (const keep of [undefined, "keep-unrecognized-values"] as const) {
        for (const payload of [
          // 130 UTF-8 bytes: a three-byte BOM followed by 127 ASCII characters.
          [
            243,
            130,
            239,
            187,
            191,
            ...Array.from({ length: 127 }, (_, i) => i),
          ],
          [243, 1, 255],
          [250, 1, 243, 1, 255],
          [251, 243, 1, 255],
        ]) {
          const bytes = binary(wire, ...payload);
          const value = serializer.fromBytes(bytes, keep);
          if (keep) {
            assert.deepEqual(serializer.toBytes(value).toBuffer(), bytes);
          }
        }
      }
    });

    it(`rejects invalid lengths and truncated payloads nested in unknown ${kind} values`, () => {
      for (const keep of [undefined, "keep-unrecognized-values"] as const) {
        for (const payload of [
          [232],
          [245, 3, 65],
          [250, 235, 255],
          [243, 3, 65],
          [243, 235, 255],
          [250, 1, 243, 3, 65],
          [251, 243, 3, 65],
        ]) {
          assert.throws(() =>
            serializer.fromBytes(binary(wire, ...payload), keep),
          );
        }
      }
    });
  }
});
