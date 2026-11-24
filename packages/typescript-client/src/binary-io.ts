import type { ByteString } from "./byte-string.js";

/** Result of encoding a struct using binary encoding format. */
export interface BinaryForm {
  /** Length (in bytes) of the binary form. */
  readonly byteLength: number;
  /** Copies the contents of the binary form into the given array buffer. */
  copyTo(target: ArrayBuffer, offset?: number): void;
  /** Copies the contents of this byte string into a new array buffer. */
  toBuffer(): ArrayBuffer;
}

/** Reads values from a binary payload. */
export class InputStream {
  constructor(
    readonly buffer: ArrayBuffer,
    keep?: "keep-unrecognized-values",
  ) {
    this.dataView = new DataView(buffer);
    this.keepUnrecognizedValues = !!keep;
  }

  readonly dataView: DataView;
  readonly keepUnrecognizedValues: boolean;
  offset = 0;

  readUint8(): number {
    return this.dataView.getUint8(this.offset++);
  }

  skip(length: number): void {
    if (length > this.buffer.byteLength - this.offset) {
      throw new RangeError("Truncated binary payload");
    }
    this.offset += length;
  }
}

type DecodeNumberFn = (stream: InputStream) => number | bigint;

// For wires [232, 241]
const DECODE_NUMBER_FNS: readonly DecodeNumberFn[] = [
  (s: InputStream): number => s.dataView.getUint16((s.offset += 2) - 2, true),
  (s: InputStream): number => s.dataView.getUint32((s.offset += 4) - 4, true),
  (s: InputStream): bigint =>
    s.dataView.getBigUint64((s.offset += 8) - 8, true),
  (stream: InputStream): number => stream.readUint8() - 256,
  (s: InputStream): number =>
    s.dataView.getUint16((s.offset += 2) - 2, true) - 65536,
  (s: InputStream): number => s.dataView.getInt32((s.offset += 4) - 4, true),
  (s: InputStream): bigint => s.dataView.getBigInt64((s.offset += 8) - 8, true),
  (s: InputStream): bigint => s.dataView.getBigInt64((s.offset += 8) - 8, true),
  (s: InputStream): number => s.dataView.getFloat32((s.offset += 4) - 4, true),
  (s: InputStream): number => s.dataView.getFloat64((s.offset += 8) - 8, true),
];

export function decodeNumber(stream: InputStream): number | bigint {
  const wire = stream.readUint8();
  if (wire > 241) {
    throw new Error(`Invalid numeric wire tag: ${wire}`);
  }
  return wire < 232 ? wire : DECODE_NUMBER_FNS[wire - 232]!(stream);
}

export function decodeUint32(stream: InputStream): number {
  const wire = stream.dataView.getUint8(stream.offset);
  if (wire > 233) {
    throw new Error(`Invalid unsigned length or variant tag: ${wire}`);
  }
  return decodeNumber(stream) as number;
}

export function decodeArrayLength(wire: number, stream: InputStream): number {
  if (wire < 246 || wire > 250) {
    throw new Error(`Invalid array wire tag: ${wire}`);
  }
  const length = wire === 250 ? decodeUint32(stream) : wire - 246;
  if (length > stream.buffer.byteLength - stream.offset) {
    throw new Error("Truncated binary array");
  }
  return length;
}

export function decodeBigInt(stream: InputStream): bigint {
  const number = decodeNumber(stream);
  return typeof number === "bigint" ? number : BigInt(Math.round(number));
}

/** Writes values to a binary payload. */
export class OutputStream implements BinaryForm {
  writeUint8(value: number): void {
    const dataView = this.reserve(1);
    dataView.setUint8(++this.offset - 1, value);
  }

  writeUint16(value: number): void {
    const dataView = this.reserve(2);
    dataView.setUint16((this.offset += 2) - 2, value, true);
  }

  writeUint32(value: number): void {
    const dataView = this.reserve(4);
    dataView.setUint32((this.offset += 4) - 4, value, true);
  }

  writeInt32(value: number): void {
    const dataView = this.reserve(4);
    dataView.setInt32((this.offset += 4) - 4, value, true);
  }

  writeHash64(value: bigint): void {
    const dataView = this.reserve(8);
    dataView.setBigUint64((this.offset += 8) - 8, value, true);
  }

  writeInt64(value: bigint): void {
    const dataView = this.reserve(8);
    dataView.setBigInt64((this.offset += 8) - 8, value, true);
  }

  writeFloat32(value: number): void {
    const dataView = this.reserve(4);
    dataView.setFloat32((this.offset += 4) - 4, value, true);
  }

  writeFloat64(value: number): void {
    const dataView = this.reserve(8);
    dataView.setFloat64((this.offset += 8) - 8, value, true);
  }

  /**
   * Encodes the given string to UTF-8 and writes the bytes to this stream.
   * Returns the number of bytes written.
   */
  putUtf8String(string: string): number {
    // We do at most 3 writes:
    //   - First, fill the current buffer as much as possible
    //   - If there is not enough room, allocate a new buffer of N bytes, where
    //       N is twice the number of remaining UTF-16 characters in the string,
    //       and write to it. This new buffer is very likely to have enough
    //       room.
    //   - If there was not enough room, try again one last time.
    //
    // See https://developer.mozilla.org/en-US/docs/Web/API/TextEncoder
    let dataView: DataView = this.dataView;
    let result = 0;
    while (string) {
      const encodeResult = textEncoder.encodeInto(
        string,
        new Uint8Array(dataView.buffer, this.offset),
      );
      this.offset += encodeResult.written;
      result += encodeResult.written;
      string = string.substring(encodeResult.read);
      if (string) {
        dataView = this.reserve(string.length * 2);
      }
    }
    return result;
  }

  putBytes(bytes: ByteString): void {
    this.reserve(bytes.byteLength);
    bytes.copyTo(this.buffer, this.offset);
    this.offset += bytes.byteLength;
  }

  finalize(): BinaryForm {
    this.flush();
    Object.freeze(this.pieces);
    Object.freeze(this);
    return this;
  }

  copyTo(target: ArrayBuffer, offset = 0): void {
    const targetArea = new Uint8Array(target);
    for (const piece of this.pieces) {
      targetArea.set(piece, offset);
      offset += piece.length;
    }
  }

  toBuffer(): ArrayBuffer {
    const result = new ArrayBuffer(this.byteLength);
    this.copyTo(result);
    return result;
  }

  /** Returns a data view with enough capacity for `bytes` more bytes. */
  private reserve(bytes: number): DataView {
    if (this.offset <= this.buffer.byteLength - bytes) {
      // Enough room in the current data view.
      return this.dataView;
    }
    this.flush();
    const lengthInBytes = Math.max(this.byteLength, bytes);
    this.offset = 0;
    this.buffer = new ArrayBuffer(lengthInBytes);
    return (this.dataView = new DataView(this.buffer));
  }

  /** Adds the current buffer to `pieces`. Updates `byteLength` accordingly. */
  private flush(): void {
    const { offset } = this;
    this.pieces.push(new Uint8Array(this.dataView.buffer, 0, offset));
    this.byteLength += offset;
  }

  buffer = new ArrayBuffer(128);
  dataView = new DataView(this.buffer);
  offset = 0;
  // The final binary form is the result of concatenating these arrays.
  // The length of each array is approximately twice the length of the previous
  // array.
  private readonly pieces: Uint8Array[] = [];
  // Updated each time `flush()` is called.
  byteLength = 0;
}

export function encodeUint32(length: number, stream: OutputStream): void {
  if (length < 232) {
    stream.writeUint8(length);
  } else if (length < 65536) {
    stream.writeUint8(232);
    stream.writeUint16(length);
  } else if (length < 4294967296) {
    stream.writeUint8(233);
    stream.writeUint32(length);
  } else {
    throw new Error(`max length exceeded: ${length}`);
  }
}

const textEncoder = new TextEncoder();

export function decodeUnused(stream: InputStream): void {
  const wire = stream.readUint8();
  if (wire < 232) {
    return;
  }
  switch (wire - 232) {
    case 0: // uint16
    case 4: // uint16 - 65536
      stream.skip(2);
      break;
    case 1: // uint32
    case 5: // int32
    case 8: // float32
      stream.skip(4);
      break;
    case 2: // hash64
    case 6: // int64
    case 7: // hash64 timestamp
    case 9: // float64
      stream.skip(8);
      break;
    case 3: // uint8 - 256
      stream.skip(1);
      break;
    case 11: // string
    case 13: {
      // bytes
      stream.skip(decodeUint32(stream));
      break;
    }
    case 15: // array length==1
    case 19: // enum value kind==1
    case 20: // enum value kind==2
    case 21: // enum value kind==3
    case 22: // enum value kind==4
      decodeUnused(stream);
      break;
    case 16: // array length==2
      decodeUnused(stream);
      decodeUnused(stream);
      break;
    case 17: // array length==3
      decodeUnused(stream);
      decodeUnused(stream);
      decodeUnused(stream);
      break;
    case 18: {
      // array length==N
      const length = decodeArrayLength(wire, stream);
      for (let i = 0; i < length; ++i) {
        decodeUnused(stream);
      }
      break;
    }
  }
}
