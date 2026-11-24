import { expect } from "buckwheat";
import { describe, it } from "mocha";
import * as skir from "../src/skir-client.js";

describe("ByteString", () => {
  const makeTestByteArray = (length = 4, start = 0): Uint8Array => {
    return Uint8Array.from({ length }, (_, i) => start + i);
  };

  const makeTestByteString = (length = 4, start = 0): skir.ByteString => {
    return skir.ByteString.sliceOf(makeTestByteArray(length, start).buffer);
  };

  const makeSlicedTestByteString = (length = 4): skir.ByteString => {
    const superByteString = makeTestByteString(length + 2, -1);
    return skir.ByteString.sliceOf(superByteString, 1, length + 1);
  };

  const toArray = (byteString: skir.ByteString): number[] => {
    return Array.from(new Uint8Array(byteString.toBuffer()));
  };

  describe("#EMPTY", () => {
    it("works", () => {
      expect(skir.ByteString.EMPTY.byteLength).toBe(0);
      expect(skir.ByteString.EMPTY.toBuffer().byteLength).toBe(0);
    });
  });

  describe("#sliceOf", () => {
    it("works when no start/end is specified", () => {
      let byteString = makeTestByteString();
      byteString = skir.ByteString.sliceOf(byteString);
      expect(byteString.byteLength).toBe(4);
      expect(toArray(byteString)).toMatch([0, 1, 2, 3]);
    });

    it("works when only start is specified", () => {
      let byteString = makeTestByteString();
      byteString = skir.ByteString.sliceOf(byteString, 1);
      expect(byteString.byteLength).toBe(3);
      expect(toArray(byteString)).toMatch([1, 2, 3]);
    });

    it("works when both start/end are specified", () => {
      let byteString = makeTestByteString();
      byteString = skir.ByteString.sliceOf(byteString, 1, 3);
      expect(byteString.byteLength).toBe(2);
      expect(toArray(byteString)).toMatch([1, 2]);
    });

    it("returns empty when start === end", () => {
      const byteString = makeTestByteString();
      expect(skir.ByteString.sliceOf(byteString, 3, 3)).toBe(
        skir.ByteString.EMPTY,
      );
    });

    it("returns empty when start > end", () => {
      const byteString = makeTestByteString();
      expect(skir.ByteString.sliceOf(byteString, 3, 0)).toBe(
        skir.ByteString.EMPTY,
      );
    });

    it("doesn't copy ByteString if it doesn't need to", () => {
      const byteString = makeTestByteString();
      expect(skir.ByteString.sliceOf(byteString, 0, 4)).toBe(byteString);
    });

    it("start can be < 0", () => {
      const byteString = makeTestByteString();
      expect(skir.ByteString.sliceOf(byteString, -1, 4)).toBe(byteString);
    });

    it("end can be > byteLength", () => {
      const byteString = makeTestByteString();
      expect(skir.ByteString.sliceOf(byteString, 0, 5)).toBe(byteString);
    });

    it("copies bytes in the ArrayBuffer", () => {
      const array = makeTestByteArray();
      const byteString = skir.ByteString.sliceOf(array.buffer);
      array[3] = 4;
      expect(toArray(byteString)).toMatch([0, 1, 2, 3]);
    });

    it("works with SharedArrayBuffer", () => {
      const sharedBuffer = new SharedArrayBuffer(4);
      const view = new Uint8Array(sharedBuffer);
      view[0] = 10;
      view[1] = 20;
      view[2] = 30;
      view[3] = 40;
      const byteString = skir.ByteString.sliceOf(sharedBuffer);
      expect(byteString.byteLength).toBe(4);
      expect(toArray(byteString)).toMatch([10, 20, 30, 40]);
    });
  });

  for (const sliced of [false, true]) {
    const description = sliced ? "on sliced instance" : "on normal instance";
    const byteString = sliced
      ? makeSlicedTestByteString(20)
      : makeTestByteString(20);
    describe(description, () => {
      it("#byteLength", () => {
        expect(byteString.byteLength).toBe(20);
      });

      it("#toBuffer", () => {
        const buffer = byteString.toBuffer();
        expect(buffer.byteLength).toBe(20);
        expect(new Uint8Array(buffer)[2]).toBe(2);
      });

      it("#copyTo", () => {
        const buffer = new ArrayBuffer(22);
        byteString.copyTo(buffer, 1);
        const array = new Uint8Array(buffer);
        expect(array[5]).toBe(4);
      });

      describe("#at()", () => {
        it("works with normal index", () => {
          expect(byteString.at(2)).toBe(2);
        });

        it("works with negative index", () => {
          expect(byteString.at(-1)).toBe(19);
        });
      });

      describe("base64", () => {
        const base64 = byteString.toBase64();
        it("#toBase64() works", () => {
          expect(base64).toBe("AAECAwQFBgcICQoLDA0ODxAREhM=");
        });
        const fromBase64 = skir.ByteString.fromBase64(base64);
        it("#fromBase64() works", () => {
          expect(toArray(fromBase64)).toMatch(toArray(byteString));
        });
      });

      describe("base16", () => {
        const array = toArray(byteString);
        const base16 = byteString.toBase16();
        it("#toBase16() works", () => {
          expect(base16).toBe("000102030405060708090a0b0c0d0e0f10111213");
        });
        it("#fromBase16() works", () => {
          const fromBase16 = skir.ByteString.fromBase16(base16);
          expect(toArray(fromBase16)).toMatch(array);
        });
        it("#fromBase16() accepts uppercase", () => {
          const fromBase16 = skir.ByteString.fromBase16(base16.toUpperCase());
          expect(toArray(fromBase16)).toMatch(array);
        });
      });
    });
  }
});
