import { expect } from "buckwheat";
import { describe, it } from "mocha";
import {
  ByteString,
  parseTypeDescriptorFromJson,
  type Json,
  type JsonFlavor,
  type MutableForm,
  type Serializer,
} from "./skir-client.js";

export class SerializerTester<T> {
  constructor(readonly serializer: Serializer<T>) {}

  reserializeAndAssert(
    input: T | MutableForm<T>,
    expected: {
      denseJson: Json;
      /** Defaults to `denseJson`. */
      readableJson?: Json;
      bytesAsBase16: string;
      /** Defaults to `denseJson`. */
      denseJsonFromReserialized?: Json;
      lossy?: true;
    },
    description?: string,
  ): void {
    const { serializer } = this;

    describe(description ?? `reserialize ${input}`, () => {
      const jsonFlavors: JsonFlavor[] = ["dense", "readable"];
      for (const flavor of jsonFlavors) {
        const expectedJson =
          flavor === "dense"
            ? expected.denseJson
            : (expected.readableJson ?? expected.denseJson);

        describe(`${flavor} JSON`, () => {
          const actualJson = serializer.toJson(input, flavor);

          it("#toJson()", () => {
            expect(actualJson).toMatch(expectedJson);
          });

          it("#toJsonCode()", () => {
            const actualJsonCode = serializer.toJsonCode(input, flavor);
            const expectedJsonCode = JSON.stringify(
              expectedJson,
              undefined,
              flavor === "dense" ? "" : "  ",
            );
            expect(actualJsonCode).toBe(expectedJsonCode);
          });

          it("#toJson() -> #fromJson() -> #toJson()", () => {
            serializer.fromJson(actualJson);
            const reserialized: T = serializer.fromJson(
              actualJson,
              "keep-unrecognized-values",
            );
            expect(serializer.toJson(reserialized, flavor)).toMatch(
              expectedJson,
            );
          });

          it("#toJsonCode() -> #fromJsonCode() -> #toJson()", () => {
            const reserialized = serializer.fromJsonCode(
              serializer.toJsonCode(input, flavor),
              "keep-unrecognized-values",
            );
            expect(serializer.toJson(reserialized, flavor)).toMatch(
              expectedJson,
            );
          });
        });
      }

      const actualBytes = serializer.toBytes(input).toBuffer();
      it("#toBytes()", () => {
        const actualBase16 = toBase16(actualBytes);
        expect(actualBase16).toBe(expected.bytesAsBase16);
      });
      serializer.fromBytes(actualBytes);
      const reserialized = serializer.fromBytes(
        actualBytes,
        "keep-unrecognized-values",
      );
      it("#toBytes() -> #fromBytes() -> #toBytes()", () => {
        const actualBase16 = toBase16(
          serializer.toBytes(reserialized).toBuffer(),
        );
        expect(actualBase16).toBe(expected.bytesAsBase16);
      });
      it("#toBytes() -> #fromBytes() -> #toJson()", () => {
        const actualDenseJson = serializer.toJson(reserialized, "dense");
        const expectedDenseJson =
          expected.denseJsonFromReserialized ?? expected.denseJson;
        expect(actualDenseJson).toMatch(expectedDenseJson);
      });

      if (!expected.lossy) {
        type Format = JsonFlavor | "bytes";
        const serialized: Record<Format, Json | ArrayBuffer> = {
          dense: serializer.toJson(input, "dense"),
          readable: serializer.toJson(input, "readable"),
          bytes: actualBytes,
        };
        const normalize = (value: Json | ArrayBuffer): Json =>
          value instanceof ArrayBuffer ? toBase16(value) : value;
        const formats: Format[] = ["dense", "readable", "bytes"];
        for (const reparse of [false, true]) {
          // Reparsing primitives returns the same serializer instance.
          if (reparse && serializer.typeDescriptor.kind === "primitive")
            continue;
          const prefix = reparse ? "parseTypeDescriptor then " : "";
          for (const source of formats) {
            for (const target of formats) {
              it(`${prefix}transform ${source} -> ${target}`, () => {
                const descriptor = reparse
                  ? parseTypeDescriptorFromJson(
                      serializer.typeDescriptor.asJson(),
                    )
                  : serializer.typeDescriptor;
                expect(
                  normalize(descriptor.transform(serialized[source], target)),
                ).toMatch(normalize(serialized[target]));
              });
            }
          }
        }
      }

      serializer.fromJson(serializer.toJson(input));
      return serializer.fromJson(
        serializer.toJson(input),
        "keep-unrecognized-values",
      );
    });
  }

  deserializeZeroAndAssert(isDefaultFn: (input: T) => boolean): void {
    const { serializer } = this;

    describe("deserialize zero", () => {
      it("from JSON", () => {
        expect(isDefaultFn(serializer.fromJson(0))).toBe(true);
      });
      it("from bytes", () => {
        const bytes = new ArrayBuffer(5);
        new TextEncoder().encodeInto("skir", new Uint8Array(bytes, 0, 4));
        expect(isDefaultFn(serializer.fromBytes(bytes))).toBe(true);
      });
    });
  }

  reserializeTypeAdapterAndAssertNoLoss(): void {
    it("reserialize type adapter", () => {
      const json = this.serializer.typeDescriptor.asJson();
      const reserialized = parseTypeDescriptorFromJson(json);
      expect(reserialized.asJson()).toMatch(json);
      expect(json).toMatch(reserialized.asJson());
    });
  }
}

export function toBase16(buffer: ArrayBuffer): string {
  const prefix = new TextDecoder().decode(new Uint8Array(buffer).slice(0, 4));
  expect(prefix).toBe("skir");
  return ByteString.sliceOf(buffer, 4).toBase16();
}
