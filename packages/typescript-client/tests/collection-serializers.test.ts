import { expect } from "buckwheat";
import { describe, it } from "mocha";
import assert from "node:assert/strict";
import { SerializerTester } from "../src/serializer_tester.js";
import * as skir from "../src/skir-client.js";
import { binary } from "./test_helpers.js";

describe("optional serializer", () => {
  const otherSerializer = skir.primitiveSerializer("int32");
  const serializer = skir.optionalSerializer(otherSerializer);
  it("is idempotent", () => {
    expect(skir.optionalSerializer(serializer)).toMatch(serializer);
  });

  const tester = new SerializerTester(serializer);

  it("#typeDescriptor", () => {
    expect(serializer.typeDescriptor).toMatch({
      kind: "optional",
      otherType: otherSerializer.typeDescriptor,
    });
  });

  it("TypeDescriptor#asJson()", () => {
    expect(serializer.typeDescriptor.asJson()).toMatch({
      type: {
        kind: "optional",
        value: {
          kind: "primitive",
          value: "int32",
        },
      },
      records: [],
    });
  });
  tester.reserializeTypeAdapterAndAssertNoLoss();

  tester.reserializeAndAssert(2, {
    denseJson: 2,
    bytesAsBase16: "02",
  });
  tester.reserializeAndAssert(null, {
    denseJson: null,
    bytesAsBase16: "ff",
  });
  tester.deserializeZeroAndAssert((i) => i === 0);
});

describe("array serializer", () => {
  const itemSerializer = skir.primitiveSerializer("int32");
  const serializer = skir.arraySerializer(itemSerializer, "foo.bar");
  const tester = new SerializerTester(serializer);

  it("rejects invalid array tags", () => {
    assert.throws(() => serializer.fromBytes(binary(244, 0)));
  });

  it("#typeDescriptor", () => {
    expect(serializer.typeDescriptor).toMatch({
      kind: "array",
      itemType: itemSerializer.typeDescriptor,
    });
  });

  it("TypeDescriptor#asJson()", () => {
    expect(serializer.typeDescriptor.asJson()).toMatch({
      type: {
        kind: "array",
        value: {
          item: {
            kind: "primitive",
            value: "int32",
          },
          key_extractor: "foo.bar",
        },
      },
      records: [],
    });
  });
  tester.reserializeTypeAdapterAndAssertNoLoss();

  tester.reserializeAndAssert([], {
    denseJson: [],
    bytesAsBase16: "f6",
  });

  tester.reserializeAndAssert([10], {
    denseJson: [10],
    bytesAsBase16: "f70a",
  });

  tester.reserializeAndAssert([10, 11], {
    denseJson: [10, 11],
    bytesAsBase16: "f80a0b",
  });

  tester.reserializeAndAssert([10, 11, 12], {
    denseJson: [10, 11, 12],
    bytesAsBase16: "f90a0b0c",
  });

  tester.reserializeAndAssert([10, 11, 12, 13], {
    denseJson: [10, 11, 12, 13],
    bytesAsBase16: "fa040a0b0c0d",
  });

  tester.deserializeZeroAndAssert((a) => a.length === 0);
});

describe("string array serializer", () => {
  const itemSerializer = skir.primitiveSerializer("string");
  const serializer = skir.arraySerializer(itemSerializer);
  const tester = new SerializerTester(serializer);

  it("TypeDescriptor#asJson()", () => {
    expect(serializer.typeDescriptor.asJson()).toMatch({
      type: {
        kind: "array",
        value: {
          item: {
            kind: "primitive",
            value: "string",
          },
          key_extractor: undefined,
        },
      },
      records: [],
    });
  });
  tester.reserializeTypeAdapterAndAssertNoLoss();

  tester.reserializeAndAssert(["foo", "bar"], {
    denseJson: ["foo", "bar"],
    bytesAsBase16: "f8f303666f6ff303626172",
  });
});

describe("bytes array serializer", () => {
  const itemSerializer = skir.primitiveSerializer("bytes");
  const serializer = skir.arraySerializer(itemSerializer);
  const tester = new SerializerTester(serializer);

  const a = skir.ByteString.fromBase64("bGlnaHQgdw==");
  const b = skir.ByteString.fromBase64("bGlnaHQgd28=");

  tester.reserializeAndAssert([a, b], {
    denseJson: [a.toBase64(), b.toBase64()],
    readableJson: ["hex:6c696768742077", "hex:6c6967687420776f"],
    bytesAsBase16: "f8f5076c696768742077f5086c6967687420776f",
  });
});
