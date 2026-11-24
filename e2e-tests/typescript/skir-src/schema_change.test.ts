import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { toBase16 } from "../../node_modules/skir-client/dist/esm/serializer_tester.js";
import {
  BarAfter,
  EnumAfter,
  FooAfter,
  FooBefore,
  RemovalAfter,
  RemovalBefore,
  Zelda,
} from "../skirout/schema_change.js";

describe("schema change", () => {
  describe("unrecognized fields", () => {
    const foo = FooAfter.create<"partial">({
      bars: [
        {
          x: 2.5,
        },
        {},
        BarAfter.create({
          x: 2.5,
          s: "S0",
        }),
        BarAfter.create({
          x: 2.0,
          s: "S1",
        }),
        BarAfter.DEFAULT,
        BarAfter.create<"partial">({
          x: 3.0,
        }),
      ],
      n: 100,
      enums: [
        EnumAfter.UNKNOWN,
        EnumAfter.A,
        EnumAfter.B,
        EnumAfter.create({ kind: "c", value: "CcC" }),
      ],
      bit: true,
    });

    it("are kept in JSON format", () => {
      const fooBefore = FooBefore.serializer.fromJson(
        FooAfter.serializer.toJson(foo),
        "keep-unrecognized-values",
      );
      const reserialized = FooAfter.serializer.fromJson(
        FooBefore.serializer.toJson(fooBefore),
        "keep-unrecognized-values",
      );
      expect(reserialized).toMatch(foo);
    });

    it("are kept in JSON format even when made mutable", () => {
      const fooBefore = FooBefore.serializer.fromJson(
        FooAfter.serializer.toJson(foo.toMutable()),
        "keep-unrecognized-values",
      );
      const reserialized = FooAfter.serializer.fromJson(
        FooBefore.serializer.toJson(fooBefore.toMutable()),
        "keep-unrecognized-values",
      );
      expect(reserialized).toMatch(foo);
    });

    it("are kept in binary format", () => {
      const fooBefore = FooBefore.serializer.fromBytes(
        FooAfter.serializer.toBytes(foo).toBuffer(),
        "keep-unrecognized-values",
      );
      const reserialized = FooAfter.serializer.fromBytes(
        FooBefore.serializer.toBytes(fooBefore).toBuffer(),
        "keep-unrecognized-values",
      );
      expect(reserialized).toMatch(foo);
    });

    it("make a struct not default", () => {
      const structHolder = Zelda.StructHolder.create({
        s: Zelda.Struct.create({
          a: 3,
        }),
      });
      const structHolderBefore = Zelda.StructHolderBefore.serializer.fromBytes(
        Zelda.StructHolder.serializer.toBytes(structHolder).toBuffer(),
        "keep-unrecognized-values",
      );
      expect(
        toBase16(
          Zelda.StructHolderBefore.serializer
            .toBytes(structHolderBefore)
            .toBuffer(),
        ),
      ).toMatch("f7f703");
    });

    it("make an enum not default", () => {
      const enumHolder = Zelda.EnumHolder.create({
        e: Zelda.Enum.A,
      });
      const enumHolderBefore = Zelda.EnumHolderBefore.serializer.fromBytes(
        Zelda.EnumHolder.serializer.toBytes(enumHolder).toBuffer(),
        "keep-unrecognized-values",
      );
      expect(
        toBase16(
          Zelda.EnumHolderBefore.serializer
            .toBytes(enumHolderBefore)
            .toBuffer(),
        ),
      ).toMatch("f701");
    });
  });

  describe("removed fields", () => {
    const before = RemovalBefore.create({
      a: "AA",
      b: "BB",
      es: [
        RemovalBefore.E.C,
        RemovalBefore.E.D,
        RemovalBefore.E.create({ kind: "e", value: "EE" }),
      ],
    });

    const expected = RemovalBefore.create<"partial">({
      b: "BB",
      es: [RemovalBefore.E.C, RemovalBefore.E.UNKNOWN, RemovalBefore.E.UNKNOWN],
    });

    it("are removed when deserializing from JSON", () => {
      const reserialized = RemovalBefore.serializer.fromJson(
        RemovalAfter.serializer.toJson(
          RemovalAfter.serializer.fromJson(
            RemovalBefore.serializer.toJson(before),
            "keep-unrecognized-values",
          ),
        ),
        "keep-unrecognized-values",
      );
      expect(reserialized).toMatch(expected);
    });

    it("are removed when deserializing from bytes", () => {
      const reserialized = RemovalBefore.serializer.fromBytes(
        RemovalAfter.serializer
          .toBytes(
            RemovalAfter.serializer.fromBytes(
              RemovalBefore.serializer.toBytes(before).toBuffer(),
              "keep-unrecognized-values",
            ),
          )
          .toBuffer(),
        "keep-unrecognized-values",
      );
      expect(reserialized).toMatch(expected);
    });
  });
});
