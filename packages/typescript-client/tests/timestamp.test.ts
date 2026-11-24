import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { SerializerTester } from "../src/serializer_tester.js";
import * as skir from "../src/skir-client.js";

describe("Timestamp", () => {
  it("#MIN is min timestamp rerpresentable as Date objects", () => {
    expect(new Date(skir.Timestamp.MIN.unixMillis).getTime()).toBe(
      -8640000000000000,
    );
    expect(new Date(skir.Timestamp.MIN.unixMillis - 1).getTime()).toBe(
      Number.NaN,
    );
  });

  it("#MAX is max timestamp rerpresentable as Date objects", () => {
    expect(new Date(skir.Timestamp.MAX.unixMillis).getTime()).toBe(
      8640000000000000,
    );
    expect(new Date(skir.Timestamp.MAX.unixMillis + 1).getTime()).toBe(
      Number.NaN,
    );
  });

  describe("#fromUnixMillis()", () => {
    it("works", () => {
      expect(skir.Timestamp.fromUnixMillis(3000).unixMillis).toBe(3000);
      expect(skir.Timestamp.fromUnixMillis(3001).unixSeconds).toBe(3.001);
    });
    it("clamp timestamps outside of valid range", () => {
      expect(
        skir.Timestamp.fromUnixMillis(skir.Timestamp.MAX.unixMillis + 1)
          .unixMillis,
      ).toBe(skir.Timestamp.MAX.unixMillis);
    });
    it("truncates to millisecond precision", () => {
      expect(skir.Timestamp.fromUnixMillis(2.8).unixMillis).toBe(3);
    });
  });

  describe("#fromUnixSeconds()", () => {
    it("works", () => {
      expect(skir.Timestamp.fromUnixSeconds(3).unixMillis).toBe(3000);
      expect(skir.Timestamp.fromUnixSeconds(3).unixSeconds).toBe(3);
    });
    it("truncates to millisecond precision", () => {
      expect(skir.Timestamp.fromUnixSeconds(2.0061).unixSeconds).toBe(2.006);
    });
  });

  it("#toDate()", () => {
    expect(
      skir.Timestamp.fromUnixMillis(1694467279837).toDate().getTime(),
    ).toBe(1694467279837);
  });

  it("#now()", () => {
    const now = skir.Timestamp.now();
    expect(now.toDate().getFullYear()).toCompare(">=", 2023);
    expect(now.toDate().getFullYear()).toCompare(
      "<=",
      new Date().getFullYear() + 1,
    );
  });

  it("#toString()", () => {
    const timestamp = skir.Timestamp.fromUnixMillis(1694467279837);
    expect(timestamp.toString()).toBe("2023-09-11T21:21:19.837Z");
  });

  it("#parse()", () => {
    const timestamp = skir.Timestamp.fromUnixMillis(1694467279837);
    const parseResult = skir.Timestamp.parse(timestamp.toString());
    expect(parseResult.unixMillis).toBe(timestamp.unixMillis);
  });
});

describe("timestamp serializer", () => {
  const serializer = skir.primitiveSerializer("timestamp");
  const tester = new SerializerTester(serializer);

  it("TypeDescriptor#asJsonCode()", () => {
    expect(serializer.typeDescriptor.asJsonCode()).toMatch(
      [
        "{",
        '  "type": {',
        '    "kind": "primitive",',
        '    "value": "timestamp"',
        "  },",
        '  "records": []',
        "}",
      ].join("\n"),
    );
    expect(
      skir
        .parseTypeDescriptorFromJsonCode(serializer.typeDescriptor.asJsonCode())
        .asJson(),
    ).toMatch(serializer.typeDescriptor.asJson());
  });

  it("can deserialize any number", () => {
    expect(serializer.fromJson("888888888888").unixMillis).toBe(888888888888);
  });

  tester.reserializeAndAssert(
    skir.Timestamp.UNIX_EPOCH,
    {
      denseJson: 0,
      readableJson: {
        unix_millis: 0,
        formatted: "1970-01-01T00:00:00.000Z",
      },
      bytesAsBase16: "00",
    },
    "reserialize Unix EPOCH",
  );

  tester.reserializeAndAssert(
    skir.Timestamp.fromUnixMillis(1692999034586),
    {
      denseJson: 1692999034586,
      readableJson: {
        unix_millis: 1692999034586,
        formatted: "2023-08-25T21:30:34.586Z",
      },
      bytesAsBase16: "efda269b2e8a010000",
    },
    "reserialize normal timestamp",
  );

  tester.reserializeAndAssert(
    skir.Timestamp.fromUnixMillis(-1692999034586),
    {
      denseJson: -1692999034586,
      readableJson: {
        unix_millis: -1692999034586,
        formatted: "1916-05-09T02:29:25.414Z",
      },
      bytesAsBase16: "ef26d964d175feffff",
    },
    "reserialize negative timestamp",
  );

  it("default JSON flavor is dense", () => {
    expect(serializer.toJson(skir.Timestamp.UNIX_EPOCH)).toBe(0);
  });
});
