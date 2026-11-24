import type { InputStream, OutputStream } from "../binary-io.js";
import {
  decodeBigInt,
  decodeNumber,
  decodeUint32,
  encodeUint32,
} from "../binary-io.js";
import { ByteString } from "../byte-string.js";
import { Timestamp } from "../timestamp.js";
import type { Json, JsonFlavor, Serializer } from "./base.js";
import { AbstractSerializer } from "./base.js";
import type {
  PrimitiveDescriptor,
  PrimitiveTypes,
  RecordDefinition,
  TypeSignature,
} from "./type-descriptor.js";

const textDecoder = new TextDecoder("utf-8", { ignoreBOM: true });

/**
 * Returns a serializer of instances of the given Skir primitive type.
 *
 * @example
 * expect(
 *   primitiveSerializer("string").toJsonCode("foo")
 * ).toBe(
 *   '"foo"'
 * );
 */
export function primitiveSerializer<P extends keyof PrimitiveTypes>(
  primitiveType: P,
): Serializer<PrimitiveTypes[P]> {
  return primitiveSerializers[primitiveType];
}

abstract class AbstractPrimitiveSerializer<P extends keyof PrimitiveTypes>
  extends AbstractSerializer<PrimitiveTypes[P]>
  implements PrimitiveDescriptor
{
  readonly kind = "primitive";

  get typeSignature(): TypeSignature {
    return {
      kind: "primitive",
      value: this.primitive,
    };
  }

  addRecordDefinitionsTo(_out: { [k: string]: RecordDefinition }): void {}

  abstract readonly primitive: P;
}

class BoolSerializer extends AbstractPrimitiveSerializer<"bool"> {
  readonly primitive = "bool";
  readonly defaultValue = false;

  toJson(input: boolean, flavor?: JsonFlavor): boolean | number {
    return flavor === "readable" ? !!input : input ? 1 : 0;
  }

  fromJson(json: Json): boolean {
    return !!json && json !== "0";
  }

  encode(input: boolean, stream: OutputStream): void {
    stream.writeUint8(input ? 1 : 0);
  }

  decode(stream: InputStream): boolean {
    return !!decodeNumber(stream);
  }
}

class Int32Serializer extends AbstractPrimitiveSerializer<"int32"> {
  readonly primitive = "int32";
  readonly defaultValue = 0;

  toJson(input: number): number {
    return input | 0;
  }

  fromJson(json: Json): number {
    // `+value` will work if the input JSON value is a string, which is
    // what the int64 serializer produces.
    return +(json as number | string) | 0;
  }

  encode(input: number, stream: OutputStream): void {
    if (input < 0) {
      if (input >= -256) {
        stream.writeUint8(235);
        stream.writeUint8(input + 256);
      } else if (input >= -65536) {
        stream.writeUint8(236);
        stream.writeUint16(input + 65536);
      } else {
        stream.writeUint8(237);
        stream.writeInt32(input >= -2147483648 ? input : -2147483648);
      }
    } else if (input < 232) {
      stream.writeUint8(input);
    } else if (input < 65536) {
      stream.writeUint8(232);
      stream.writeUint16(input);
    } else {
      stream.writeUint8(233);
      stream.writeUint32(input <= 2147483647 ? input : 2147483647);
    }
  }

  decode(stream: InputStream): number {
    return Number(decodeNumber(stream)) | 0;
  }
}

const int32_Serializer = new Int32Serializer();

abstract class FloatSerializer<
  P extends "float32" | "float64",
> extends AbstractPrimitiveSerializer<P> {
  readonly defaultValue = 0;

  toJson(input: number): number | string {
    if (Number.isFinite(input)) {
      return input;
    } else if (typeof input === "number") {
      // If the number is NaN or +/- Infinity, return a JSON string.
      return input.toString();
    }
    throw new TypeError();
  }

  fromJson(json: Json): number {
    return +(json as number | string);
  }

  decode(stream: InputStream): number {
    return Number(decodeNumber(stream));
  }

  override isDefault(input: number): boolean {
    // Needs to work for NaN.
    return input === 0;
  }
}

class Float32Serializer extends FloatSerializer<"float32"> {
  readonly primitive = "float32";

  encode(input: number, stream: OutputStream): void {
    if (input === 0) {
      stream.writeUint8(0);
    } else {
      stream.writeUint8(240);
      stream.writeFloat32(input);
    }
  }
}

class Float64Serializer extends FloatSerializer<"float64"> {
  readonly primitive = "float64";

  encode(input: number, stream: OutputStream): void {
    if (input === 0) {
      stream.writeUint8(0);
    } else {
      stream.writeUint8(241);
      stream.writeFloat64(input);
    }
  }
}

abstract class AbstractBigIntSerializer<
  P extends "int64" | "hash64",
> extends AbstractPrimitiveSerializer<P> {
  readonly defaultValue = BigInt(0);

  fromJson(json: Json): bigint {
    try {
      return BigInt(json as number | string);
    } catch (e) {
      if (typeof json === "number") {
        return BigInt(Math.round(json));
      } else {
        throw e;
      }
    }
  }
}

const MIN_INT64 = BigInt("-9223372036854775808");

const MAX_INT64 = BigInt("9223372036854775807");

class Int64Serializer extends AbstractBigIntSerializer<"int64"> {
  readonly primitive = "int64";

  toJson(input: bigint): number | string {
    // 9007199254740991 == Number.MAX_SAFE_INTEGER
    if (-9007199254740991 <= input && input <= 9007199254740991) {
      return Number(input);
    }
    const s = BigInt(input).toString();
    // Clamp the number if it's out of bounds.
    return s.length <= 18
      ? // Small optimization for "small" numbers. The max int64 has 19 digits.
        s
      : input < MIN_INT64
        ? MIN_INT64.toString()
        : input < MAX_INT64
          ? s
          : MAX_INT64.toString();
  }

  encode(input: bigint, stream: OutputStream): void {
    if (input) {
      if (-2147483648 <= input && input <= 2147483647) {
        int32_Serializer.encode(Number(input), stream);
      } else {
        stream.writeUint8(238);
        // Clamp the number if it's out of bounds.
        stream.writeInt64(
          input < MIN_INT64 ? MIN_INT64 : input < MAX_INT64 ? input : MAX_INT64,
        );
      }
    } else {
      stream.writeUint8(0);
    }
  }

  decode(stream: InputStream): bigint {
    return decodeBigInt(stream);
  }
}

const MAX_HASH64 = BigInt("18446744073709551615");

class Hash64Serializer extends AbstractBigIntSerializer<"hash64"> {
  readonly primitive = "hash64";

  toJson(input: bigint): number | string {
    if (input <= 9007199254740991) {
      return input <= 0 ? 0 : Number(input);
    }
    input = BigInt(input);
    return MAX_HASH64 < input ? MAX_HASH64.toString() : input.toString();
  }

  encode(input: bigint, stream: OutputStream): void {
    if (input < 232) {
      stream.writeUint8(input <= 0 ? 0 : Number(input));
    } else if (input < 4294967296) {
      if (input < 65536) {
        stream.writeUint8(232);
        stream.writeUint16(Number(input));
      } else {
        stream.writeUint8(233);
        stream.writeUint32(Number(input));
      }
    } else {
      stream.writeUint8(234);
      stream.writeHash64(input <= MAX_HASH64 ? input : MAX_HASH64);
    }
  }

  decode(stream: InputStream): bigint {
    return decodeBigInt(stream);
  }
}

type TimestampReadableJson = {
  unix_millis: number;
  formatted: string;
};

class TimestampSerializer extends AbstractPrimitiveSerializer<"timestamp"> {
  readonly primitive = "timestamp";
  readonly defaultValue = Timestamp.UNIX_EPOCH;

  toJson(
    input: Timestamp,
    flavor?: JsonFlavor,
  ): number | TimestampReadableJson {
    return flavor === "readable"
      ? {
          unix_millis: input.unixMillis,
          formatted: input.toDate().toISOString(),
        }
      : input.unixMillis;
  }

  fromJson(json: Json): Timestamp {
    return Timestamp.fromUnixMillis(
      typeof json === "number"
        ? json
        : typeof json === "string"
          ? +json
          : (json as TimestampReadableJson)["unix_millis"],
    );
  }

  encode(input: Timestamp, stream: OutputStream): void {
    const { unixMillis } = input;
    if (unixMillis) {
      stream.writeUint8(239);
      stream.writeInt64(BigInt(unixMillis));
    } else {
      stream.writeUint8(0);
    }
  }

  decode(stream: InputStream): Timestamp {
    const unixMillis = decodeNumber(stream);
    return Timestamp.fromUnixMillis(Number(unixMillis));
  }

  override isDefault(input: Timestamp): boolean {
    return !input.unixMillis;
  }
}

class StringSerializer extends AbstractPrimitiveSerializer<"string"> {
  readonly primitive = "string";
  readonly defaultValue = "";

  toJson(input: string): string {
    // Unicode mode leaves valid surrogate pairs intact.
    return input.replace(/[\uD800-\uDFFF]/gu, "\uFFFD");
  }

  fromJson(json: Json): string {
    if (typeof json === "string") {
      // Reuse toJson's lone-surrogate sanitization when reading JSON.
      return this.toJson(json);
    }
    if (json === 0) {
      return "";
    }
    throw this.newTypeError(json);
  }

  encode(input: string, stream: OutputStream): void {
    if (typeof input !== "string") {
      throw this.newTypeError(input);
    }
    if (!input) {
      stream.writeUint8(242);
      return;
    }
    stream.writeUint8(243);
    // We don't know the length of the UTF-8 string until we actually encode the
    // string. We just know that it's at most 3 times the length of the input
    // string.
    const maxEncodedLength = input.length * 3;
    // Write zero in place of the UTF-8 sequence length. We will override this
    // number later.
    if (maxEncodedLength < 232) {
      stream.writeUint8(0);
    } else if (maxEncodedLength < 65536) {
      stream.writeUint8(232);
      stream.writeUint16(0);
    } else {
      stream.writeUint8(233);
      stream.writeUint32(0);
    }
    const { dataView, offset } = stream;
    // Write the UTF-8 string and record the number of bytes written.
    const encodedLength = stream.putUtf8String(input);
    // Write the length of the UTF-8 string where we wrote 0.
    if (maxEncodedLength < 232) {
      dataView.setUint8(offset - 1, encodedLength);
    } else if (maxEncodedLength < 65536) {
      dataView.setUint16(offset - 2, encodedLength, true);
    } else {
      dataView.setUint32(offset - 4, encodedLength, true);
    }
  }

  decode(stream: InputStream): string {
    const wire = stream.readUint8();
    if (wire === 0 || wire === 242) {
      return "";
    }
    if (wire !== 243) {
      throw new Error(`Invalid string wire tag: ${wire}`);
    }
    const encodedLength = decodeUint32(stream);
    return textDecoder.decode(
      new Uint8Array(
        stream.buffer,
        (stream.offset += encodedLength) - encodedLength,
        encodedLength,
      ),
    );
  }

  override isDefault(input: string): boolean {
    return input === "";
  }

  private newTypeError(actual: unknown): TypeError {
    return new TypeError(`expected: string; actual: ${typeof actual}`);
  }
}

class ByteStringSerializer extends AbstractPrimitiveSerializer<"bytes"> {
  readonly primitive = "bytes";
  readonly defaultValue = ByteString.EMPTY;

  toJson(input: ByteString, flavor?: JsonFlavor): string {
    return flavor === "readable" ? "hex:" + input.toBase16() : input.toBase64();
  }

  fromJson(json: Json): ByteString {
    if (json === 0) {
      return ByteString.EMPTY;
    }
    const string = json as string;
    return string.startsWith("hex:")
      ? ByteString.fromBase16(string.substring(4))
      : ByteString.fromBase64(string);
  }

  encode(input: ByteString, stream: OutputStream): void {
    const { byteLength } = input;
    if (byteLength) {
      stream.writeUint8(245);
      encodeUint32(byteLength, stream);
      stream.putBytes(input);
    } else {
      stream.writeUint8(244);
    }
  }

  decode(stream: InputStream): ByteString {
    const wire = stream.readUint8();
    if (wire === 0 || wire === 244) {
      return ByteString.EMPTY;
    }
    if (wire !== 245) {
      throw new Error(`Invalid bytes wire tag: ${wire}`);
    }
    const lengthInBytes = decodeUint32(stream);
    const start = stream.offset;
    stream.skip(lengthInBytes);
    return ByteString.sliceOf(stream.buffer, start, stream.offset);
  }

  override isDefault(input: ByteString): boolean {
    return !input.byteLength;
  }
}

const primitiveSerializers: {
  [P in keyof PrimitiveTypes]: Serializer<PrimitiveTypes[P]>;
} = {
  bool: new BoolSerializer(),
  int32: int32_Serializer,
  int64: new Int64Serializer(),
  hash64: new Hash64Serializer(),
  float32: new Float32Serializer(),
  float64: new Float64Serializer(),
  timestamp: new TimestampSerializer(),
  string: new StringSerializer(),
  bytes: new ByteStringSerializer(),
};
