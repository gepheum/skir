import { expect } from "buckwheat";
import { describe, it } from "mocha";
import assert from "node:assert/strict";
import { SerializerTester } from "../src/serializer_tester.js";
import * as skir from "../src/skir-client.js";
import { binary, defineStruct } from "./test_helpers.js";

for (const primitive of [
  "bool",
  "int32",
  "int64",
  "hash64",
  "float32",
  "float64",
  "timestamp",
  "string",
  "bytes",
] as const) {
  describe(`${primitive} type descriptor`, () => {
    const serializer = skir.primitiveSerializer(primitive);

    it("#typeDescriptor", () => {
      expect(serializer.typeDescriptor).toMatch({
        kind: "primitive",
        primitive,
      });
    });

    it("#asJson()", () => {
      expect(serializer.typeDescriptor.asJson()).toMatch({
        type: { kind: "primitive", value: primitive },
        records: [],
      });
    });

    new SerializerTester(serializer).reserializeTypeAdapterAndAssertNoLoss();
  });
}

describe("bool serializer", () => {
  const serializer = skir.primitiveSerializer("bool");
  const tester = new SerializerTester(serializer);

  it("from number", () => {
    expect(serializer.fromJsonCode("888888")).toBe(true);
    expect(serializer.fromJsonCode('"0"')).toBe(false);
    expect(
      serializer.fromBytes(
        skir.primitiveSerializer("int32").toBytes(888888).toBuffer(),
      ),
    ).toBe(true);
  });

  tester.reserializeAndAssert(true, {
    denseJson: 1,
    readableJson: true,
    bytesAsBase16: "01",
  });
  tester.reserializeAndAssert(false, {
    denseJson: 0,
    readableJson: false,
    bytesAsBase16: "00",
  });
  tester.deserializeZeroAndAssert((input) => input === false);
});

describe("int32 serializer", () => {
  const serializer = skir.primitiveSerializer("int32");
  const tester = new SerializerTester(serializer);

  it("rejects incorrect headers and trailing bytes", () => {
    assert.throws(() =>
      serializer.fromBytes(Uint8Array.from([0, 0, 0, 0, 1]).buffer),
    );
    assert.throws(() => serializer.fromBytes(binary(1, 2)));
  });

  tester.reserializeAndAssert(2, {
    denseJson: 2,
    bytesAsBase16: "02",
  });
  tester.reserializeAndAssert(0, {
    denseJson: 0,
    bytesAsBase16: "00",
  });
  tester.reserializeAndAssert(-1, {
    denseJson: -1,
    bytesAsBase16: "ebff",
  });
  tester.reserializeAndAssert(2.8, {
    denseJson: 2,
    bytesAsBase16: "02",
  });
  tester.reserializeAndAssert(-3.8, {
    denseJson: -3,
    bytesAsBase16: "ebfc",
    denseJsonFromReserialized: -4,
    lossy: true,
  });
  tester.reserializeAndAssert(231, {
    denseJson: 231,
    bytesAsBase16: "e7",
  });
  tester.reserializeAndAssert(232, {
    denseJson: 232,
    bytesAsBase16: "e8e800",
  });
  tester.reserializeAndAssert(65535, {
    denseJson: 65535,
    bytesAsBase16: "e8ffff",
  });
  tester.reserializeAndAssert(65536, {
    denseJson: 65536,
    bytesAsBase16: "e900000100",
  });
  tester.reserializeAndAssert(2147483647, {
    denseJson: 2147483647,
    bytesAsBase16: "e9ffffff7f",
  });
  tester.reserializeAndAssert(-255, {
    denseJson: -255,
    bytesAsBase16: "eb01",
  });
  tester.reserializeAndAssert(-256, {
    denseJson: -256,
    bytesAsBase16: "eb00",
  });
  tester.reserializeAndAssert(-257, {
    denseJson: -257,
    bytesAsBase16: "ecfffe",
  });
  tester.reserializeAndAssert(-65536, {
    denseJson: -65536,
    bytesAsBase16: "ec0000",
  });
  tester.reserializeAndAssert(-65537, {
    denseJson: -65537,
    bytesAsBase16: "edfffffeff",
  });
  tester.reserializeAndAssert(-2147483648, {
    denseJson: -2147483648,
    bytesAsBase16: "ed00000080",
  });

  it("accepts string", () => {
    expect(serializer.fromJson("0")).toBe(0);
  });

  it("transforms to integer", () => {
    expect(serializer.fromJson("2.3")).toBe(2);
  });

  it("accepts NaN", () => {
    expect(serializer.fromJson("NaN")).toBe(0);
  });

  it("accepts Infinity", () => {
    expect(serializer.fromJson("Infinity")).toBe(0);
  });

  it("accepts -Infinity", () => {
    expect(serializer.fromJson("-Infinity")).toBe(0);
  });

  it("accepts numbers out of int32 range", () => {
    expect(serializer.fromJson(2147483648)).toBe(-2147483648);
    expect(serializer.fromJson(-2147483649)).toBe(2147483647);
    expect(
      serializer.fromBytes(
        skir
          .primitiveSerializer("int64")
          .toBytes(BigInt(2147483648))
          .toBuffer(),
      ),
    ).toBe(-2147483648);
  });

  it("accepts booleans", () => {
    expect(serializer.fromJson(false)).toBe(0);
    expect(serializer.fromJson(true)).toBe(1);
  });
});

describe("int64 serializer", () => {
  const serializer = skir.primitiveSerializer("int64");
  const tester = new SerializerTester(serializer);

  it("can deserialize any number", () => {
    expect(serializer.fromJson(3.14)).toBe(BigInt(3));
  });

  tester.reserializeAndAssert(BigInt("888888888888"), {
    denseJson: 888888888888,
    bytesAsBase16: "ee380ee8f5ce000000",
  });
  // Numbers outside of bounds are clamped.
  tester.reserializeAndAssert(BigInt("9223372036854775808"), {
    denseJson: "9223372036854775807",
    bytesAsBase16: "eeffffffffffffff7f",
  });
  tester.reserializeAndAssert(BigInt("-9223372036854775809"), {
    denseJson: "-9223372036854775808",
    bytesAsBase16: "ee0000000000000080",
  });
  tester.reserializeAndAssert(BigInt("0"), {
    denseJson: 0,
    bytesAsBase16: "00",
  });
  tester.deserializeZeroAndAssert(
    (i) => typeof i === "bigint" && Number(i) === 0,
  );
  it("accepts number", () => {
    expect(serializer.fromJson(123)).toBe(BigInt(123));
  });
  it("accepts number outside of range", () => {
    expect(serializer.fromJson("-99999999999999999999999999")).toBe(
      BigInt("-99999999999999999999999999"),
    );
  });
});

describe("hash64 serializer", () => {
  const serializer = skir.primitiveSerializer("hash64");
  const tester = new SerializerTester(serializer);

  it("can deserialize any number", () => {
    expect(serializer.fromJson(3.14)).toBe(BigInt(3));
  });

  tester.reserializeAndAssert(BigInt("888888888888"), {
    denseJson: 888888888888,
    bytesAsBase16: "ea380ee8f5ce000000",
  });
  tester.reserializeAndAssert(BigInt("4294967295"), {
    denseJson: 4294967295,
    bytesAsBase16: "e9ffffffff",
  });
  // Numbers outside of bounds are clamped.
  tester.reserializeAndAssert(BigInt("18446744073709551616"), {
    denseJson: "18446744073709551615",
    bytesAsBase16: "eaffffffffffffffff",
  });
  tester.reserializeAndAssert(BigInt("-1"), {
    denseJson: 0,
    bytesAsBase16: "00",
  });
  tester.reserializeAndAssert(BigInt("0"), {
    denseJson: 0,
    bytesAsBase16: "00",
  });
  tester.deserializeZeroAndAssert(
    (i) => typeof i === "bigint" && Number(i) === 0,
  );
  it("accepts number", () => {
    expect(serializer.fromJson(123)).toBe(BigInt(123));
  });
  it("accepts number outside of range", () => {
    expect(serializer.fromJson("-99999999999999999999999999")).toBe(
      BigInt("-99999999999999999999999999"),
    );
  });
});

describe("float32 serializer", () => {
  const serializer = skir.primitiveSerializer("float32");
  const tester = new SerializerTester(serializer);

  it("can deserialize any number", () => {
    expect(serializer.fromJson("1111111111")).toMatch(1111111111);
    expect(
      serializer.fromJson("1111111111111111111111111111111111111111"),
    ).toMatch(1.1111111111111112e39);
  });

  tester.reserializeAndAssert(2, {
    denseJson: 2,
    bytesAsBase16: "f000000040",
  });
  tester.reserializeAndAssert(0, {
    denseJson: 0,
    bytesAsBase16: "00",
  });
  tester.reserializeAndAssert(-1, {
    denseJson: -1,
    bytesAsBase16: "f0000080bf",
  });
  tester.reserializeAndAssert(-1.5, {
    denseJson: -1.5,
    bytesAsBase16: "f00000c0bf",
  });
  tester.reserializeAndAssert(2.8, {
    denseJson: 2.8,
    bytesAsBase16: "f033333340",
    denseJsonFromReserialized: 2.799999952316284,
    lossy: true,
  });
  tester.reserializeAndAssert(-3.8, {
    denseJson: -3.8,
    bytesAsBase16: "f0333373c0",
    denseJsonFromReserialized: -3.799999952316284,
    lossy: true,
  });
  tester.reserializeAndAssert(Number.NaN, {
    denseJson: "NaN",
    bytesAsBase16: "f00000c07f",
  });
  tester.reserializeAndAssert(Number.POSITIVE_INFINITY, {
    denseJson: "Infinity",
    bytesAsBase16: "f00000807f",
  });
  tester.reserializeAndAssert(Number.NEGATIVE_INFINITY, {
    denseJson: "-Infinity",
    bytesAsBase16: "f0000080ff",
  });
  it("accepts string", () => {
    expect(serializer.fromJson("0")).toBe(0);
    expect(serializer.fromJson("2.5")).toBe(2.5);
  });
});

describe("float64 serializer", () => {
  const serializer = skir.primitiveSerializer("float64");
  const tester = new SerializerTester(serializer);

  tester.reserializeAndAssert(2, {
    denseJson: 2,
    bytesAsBase16: "f10000000000000040",
  });
  tester.reserializeAndAssert(0, {
    denseJson: 0,
    bytesAsBase16: "00",
  });
  tester.reserializeAndAssert(-1, {
    denseJson: -1,
    bytesAsBase16: "f1000000000000f0bf",
  });
  tester.reserializeAndAssert(2.8, {
    denseJson: 2.8,
    bytesAsBase16: "f16666666666660640",
  });
  tester.reserializeAndAssert(-3.8, {
    denseJson: -3.8,
    bytesAsBase16: "f16666666666660ec0",
  });
  tester.reserializeAndAssert(Number.NaN, {
    denseJson: "NaN",
    bytesAsBase16: "f1000000000000f87f",
  });
  tester.reserializeAndAssert(Number.POSITIVE_INFINITY, {
    denseJson: "Infinity",
    bytesAsBase16: "f1000000000000f07f",
  });
  tester.reserializeAndAssert(Number.NEGATIVE_INFINITY, {
    denseJson: "-Infinity",
    bytesAsBase16: "f1000000000000f0ff",
  });
  it("accepts string", () => {
    expect(serializer.fromJson("0")).toBe(0);
    expect(serializer.fromJson("2.5")).toBe(2.5);
  });
});

describe("string serializer", () => {
  const serializer = skir.primitiveSerializer("string");
  const tester = new SerializerTester(serializer);

  tester.reserializeAndAssert("", {
    denseJson: "",
    bytesAsBase16: "f2",
  });
  tester.reserializeAndAssert("Foôbar", {
    denseJson: "Foôbar",
    bytesAsBase16: "f307466fc3b4626172",
  });
  tester.reserializeAndAssert('Foo\n"bar"', {
    denseJson: 'Foo\n"bar"',
    bytesAsBase16: "f309466f6f0a2262617222",
  });
  tester.reserializeAndAssert(
    "é".repeat(5000),
    {
      denseJson: "é".repeat(5000),
      bytesAsBase16: `f3e81027${"c3a9".repeat(5000)}`,
    },
    'reserialize "é".repeat(5000)',
  );
  // See https://stackoverflow.com/questions/55056322/maximum-utf-8-string-size-given-utf-16-size
  tester.reserializeAndAssert(
    "\uFFFF".repeat(5000),
    {
      denseJson: "\uFFFF".repeat(5000),
      bytesAsBase16: `f3e8983a${"efbfbf".repeat(5000)}`,
    },
    'reserialize "\\uFFFF".repeat(5000)',
  );
  tester.deserializeZeroAndAssert((s) => s === "");

  it("sanitizes lone surrogates when encoding to binary and JSON", () => {
    const input = "\uFEFF😀\uDC00\uD800z";
    const expected = "\uFEFF😀\uFFFD\uFFFDz";
    const bytes = serializer.toBytes(input).toBuffer();
    expect(serializer.fromBytes(bytes)).toBe(expected);
    expect(serializer.toJson(input)).toBe(expected);
    expect(serializer.fromJson(input)).toBe(expected);
  });

  const StringRecord = defineStruct({ text: "string" });

  it("round-trips strings in optional, array, and nested fields", () => {
    const stringType = { kind: "primitive", primitive: "string" } as const;
    const Record = defineStruct({
      optional: { kind: "optional", other: stringType },
      items: { kind: "array", item: stringType },
      nested: { kind: "record", ctor: StringRecord },
    });
    const text = "\uFEFF😀";
    const json = [text, [text], [text]];
    const serializer = Record.serializer;
    const input = serializer.fromJson(json);
    assert.deepEqual(serializer.toJson(input), json);
    assert.deepEqual(
      serializer.toJson(
        serializer.fromBytes(serializer.toBytes(input).toBuffer()),
      ),
      json,
    );
    assert.deepEqual(serializer.toJson(serializer.fromJson(0)), []);
  });

  it("record serialization rejects non-string values in string fields", () => {
    for (const text of [null, false, 0]) {
      assert.throws(() => StringRecord.serializer.toJson({ text }), TypeError);
      assert.throws(
        () => StringRecord.serializer.toJson({ text }, "readable"),
        TypeError,
      );
      assert.throws(() => StringRecord.serializer.toBytes({ text }), TypeError);
    }
  });

  it("record deserialization rejects non-string JSON values in string fields", () => {
    for (const text of [null, false]) {
      assert.throws(
        () => StringRecord.serializer.fromJson({ text }),
        TypeError,
      );
    }
  });

  it("replaces malformed UTF-8 in standalone strings and fields", () => {
    assert.equal(
      serializer.fromBytes(binary(243, 3, 237, 160, 128)),
      "\uFFFD\uFFFD\uFFFD",
    );
    assert.equal(
      StringRecord.serializer.fromBytes(binary(247, 243, 1, 255)).text,
      "\uFFFD",
    );
  });

  it("rejects invalid string tags, lengths and missing payload bytes", () => {
    for (const payload of [
      [247, 1, 65],
      [243, 235, 255],
      [243, 3, 65],
    ]) {
      assert.throws(() => serializer.fromBytes(binary(...payload)));
    }
  });

  it("accepts complete payloads in skipped string and byte fields", () => {
    for (const tag of [243, 245]) {
      assert.equal(
        StringRecord.serializer.fromBytes(binary(248, 242, tag, 1, 255)).text,
        "",
      );
    }
  });

  it("reads the next value after skipped string and byte fields", () => {
    const records = skir.arraySerializer(StringRecord.serializer);
    for (const tag of [243, 245]) {
      const input = binary(248, 248, 242, tag, 1, 65, 247, 243, 1, 66);
      assert.deepEqual(records.toJson(records.fromBytes(input)), [[], ["B"]]);
    }
  });

  it("rejects invalid lengths in skipped string and byte fields", () => {
    for (const tag of [243, 245]) {
      assert.throws(() =>
        StringRecord.serializer.fromBytes(binary(248, 242, tag, 235, 255)),
      );
    }
  });

  it("rejects missing payload bytes in skipped string and byte fields", () => {
    for (const tag of [243, 245]) {
      assert.throws(
        () => StringRecord.serializer.fromBytes(binary(248, 242, tag, 2, 65)),
        RangeError,
      );
    }
  });
});

describe("bytes serializer", () => {
  const serializer = skir.primitiveSerializer("bytes");
  const tester = new SerializerTester(serializer);

  for (const length of [122, 123, 124, 128, 130, 256, 1000]) {
    it(`preserves ${length} bytes across output buffer boundaries`, () => {
      const bytes = Uint8Array.from({ length }, (_, i) => i % 256).buffer;
      const value = skir.ByteString.sliceOf(bytes);
      assert.deepEqual(
        serializer.fromBytes(serializer.toBytes(value).toBuffer()).toBuffer(),
        bytes,
      );
      const array = skir.arraySerializer(serializer);
      assert.deepEqual(
        array
          .fromBytes(array.toBytes([value, value]).toBuffer())
          .map((v) => v.toBuffer()),
        [bytes, bytes],
      );
    });
  }

  it("rejects invalid bytes tags, lengths and truncated payloads", () => {
    for (const bytes of [
      binary(247, 1, 65),
      binary(245, 3, 65),
      binary(245, 235, 255),
      binary(245, 234, 0, 0, 0, 0, 0, 0, 0, 0),
      binary(245, 241, 0, 0, 0, 0, 0, 0, 248, 63),
    ]) {
      assert.throws(() => serializer.fromBytes(bytes));
    }
  });

  tester.reserializeAndAssert(skir.ByteString.fromBase64("abc123"), {
    denseJson: "abc12w==",
    readableJson: "hex:69b735db",
    bytesAsBase16: "f50469b735db",
  });
  tester.reserializeAndAssert(skir.ByteString.EMPTY, {
    denseJson: "",
    readableJson: "hex:",
    bytesAsBase16: "f4",
  });
  tester.deserializeZeroAndAssert((s) => s.byteLength === 0);
});
