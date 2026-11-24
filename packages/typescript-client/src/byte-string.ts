/** An immutable array of bytes. */
export class ByteString {
  /**
   * Returns an immutable byte string containing all the bytes of `input` from
   * `start`, inclusive, up to `end`, exclusive.
   *
   * If `input` is an `ArrayBuffer`, this function copies the bytes. Otherwise
   * this function returns a sliced view of the input `ByteString`.
   *
   * @example <caption>Copy an array buffer into a byte string</caption>
   * const byteString = ByteString.sliceOf(arrayBuffer);
   */
  static sliceOf(
    input: ArrayBuffer | SharedArrayBuffer | ByteString,
    start = 0,
    end?: number,
  ): ByteString {
    const { byteLength } = input;
    if (start < 0) {
      start = 0;
    }
    if (end === undefined || end > byteLength) {
      end = byteLength;
    }
    if (end <= start) {
      return ByteString.EMPTY;
    }
    if (input instanceof ByteString) {
      if (start <= 0 && byteLength <= end) {
        // Don't copy the ByteString itself.
        return input;
      } else {
        // Don't copy the ArrayBuffer.
        const newByteOffset = input.byteOffset + start;
        const newByteLength = end - start;
        return new ByteString(input.arrayBuffer, newByteOffset, newByteLength);
      }
    } else if (input instanceof ArrayBuffer) {
      return new ByteString(input.slice(start, end));
    } else if (input instanceof SharedArrayBuffer) {
      const slice = input.slice(start, end);
      const newBuffer = new ArrayBuffer(slice.byteLength);
      new Uint8Array(newBuffer).set(new Uint8Array(slice));
      return new ByteString(newBuffer);
    } else {
      const _: never = input;
      throw new TypeError(_);
    }
  }

  /**
   * Decodes a Base64 string, which can be obtained by calling `toBase64()`.
   *
   * @throws if the given string is not a valid Base64 string.
   * @see https://en.wikipedia.org/wiki/Base64
   */
  static fromBase64(base64: string): ByteString {
    // See https://developer.mozilla.org/en-US/docs/Glossary/Base64
    const binaryString: string = atob(base64);
    const array = Uint8Array.from(binaryString, (m) => m.codePointAt(0)!);
    return new this(array.buffer);
  }

  /**
   * Decodes a hexadecimal string, which can be obtained by calling
   * `toBase16()`.
   *
   * @throws if the given string is not a valid Base64 string.
   */
  static fromBase16(base16: string): ByteString {
    const bytes = new Uint8Array(base16.length / 2);
    for (let i = 0; i < bytes.length; ++i) {
      const byte = parseInt(base16.substring(i * 2, i * 2 + 2), 16);
      if (Number.isNaN(byte)) {
        throw new Error("Not a valid Base64 string");
      }
      bytes[i] = byte;
    }
    return new ByteString(bytes.buffer);
  }

  /** An empty byte string. */
  static readonly EMPTY = new ByteString(new ArrayBuffer(0));

  /** Copies the contents of this byte string into the given array buffer. */
  copyTo(target: ArrayBuffer, targetOffset = 0): void {
    new Uint8Array(target).set(this.uint8Array, targetOffset);
  }

  /** Copies the contents of this byte string into a new array buffer. */
  toBuffer(): ArrayBuffer {
    return this.arrayBuffer.slice(
      this.byteOffset,
      this.byteOffset + this.byteLength,
    );
  }

  /**
   * Encodes this byte string into a Base64 string.
   *
   * @see https://en.wikipedia.org/wiki/Base64
   */
  toBase64(): string {
    // See https://developer.mozilla.org/en-US/docs/Glossary/Base64
    const binaryString = Array.from(this.uint8Array, (x) =>
      String.fromCodePoint(x),
    ).join("");
    return btoa(binaryString);
  }

  /** Encodes this byte string into a hexadecimal string. */
  toBase16(): string {
    return [...this.uint8Array]
      .map((x) => x.toString(16).padStart(2, "0"))
      .join("");
  }

  at(index: number): number | undefined {
    return this.uint8Array[index < 0 ? index + this.byteLength : index];
  }

  toString(): string {
    return `ByteString(${this.byteLength})`;
  }

  private constructor(
    private readonly arrayBuffer: ArrayBuffer,
    private readonly byteOffset = 0,
    /** The length of this byte string. */
    readonly byteLength = arrayBuffer.byteLength,
  ) {
    this.uint8Array = new Uint8Array(arrayBuffer, byteOffset, byteLength);
    Object.freeze(this);
  }

  private readonly uint8Array: Uint8Array;
}
