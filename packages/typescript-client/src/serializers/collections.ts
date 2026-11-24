import type { InputStream, OutputStream } from "../binary-io.js";
import { decodeArrayLength, encodeUint32 } from "../binary-io.js";
import { _EMPTY_ARRAY, freezeArray } from "../codegen-runtime/base.js";
import type {
  InternalSerializer,
  Json,
  JsonFlavor,
  Serializer,
} from "./base.js";
import { AbstractSerializer } from "./base.js";
import type {
  ArrayDescriptor,
  OptionalDescriptor,
  RecordDefinition,
  TypeDescriptor,
  TypeSignature,
} from "./type-descriptor.js";

/**
 * Returns a serializer of arrays of `Item`s.
 *
 * @example
 * expect(
 *   arraySerializer(User.serializer).toJsonCode([JANE, JOE])
 * ).toBe(
 *   '[["jane"],["joe"]]'
 * );
 */
export function arraySerializer<Item>(
  item: Serializer<Item>,
  keyChain?: string,
): Serializer<ReadonlyArray<Item>> {
  if (
    keyChain !== undefined &&
    !/^[a-z_][a-z0-9_]*(\.[a-z_][a-z0-9_]*)*$/.test(keyChain)
  ) {
    throw new Error(`Invalid keyChain "${keyChain}"`);
  }
  return new ArraySerializerImpl(item as InternalSerializer<Item>, keyChain);
}

/** Returns a serializer of nullable `T`s. */
export function optionalSerializer<T>(
  other: Serializer<T>,
): Serializer<T | null> {
  return other instanceof OptionalSerializerImpl
    ? other
    : new OptionalSerializerImpl(other as InternalSerializer<T>);
}

export class ArraySerializerImpl<Item>
  extends AbstractSerializer<readonly Item[]>
  implements ArrayDescriptor<readonly Item[]>
{
  constructor(
    readonly itemSerializer: InternalSerializer<Item>,
    readonly keyExtractor?: string,
  ) {
    super();
  }

  readonly kind = "array";
  readonly defaultValue = _EMPTY_ARRAY;

  toJson(input: ReadonlyArray<Item>, flavor?: JsonFlavor): Json[] {
    return input.map((e) => this.itemSerializer.toJson(e, flavor));
  }

  fromJson(json: Json, keep?: "keep-unrecognized-values"): ReadonlyArray<Item> {
    if (json === 0) {
      return _EMPTY_ARRAY;
    }
    return freezeArray(
      (json as readonly Json[]).map((e) =>
        this.itemSerializer.fromJson(e, keep),
      ),
    );
  }

  encode(input: ReadonlyArray<Item>, stream: OutputStream): void {
    const { length } = input;
    if (length <= 3) {
      stream.writeUint8(246 + length);
    } else {
      stream.writeUint8(250);
      encodeUint32(length, stream);
    }
    const { itemSerializer } = this;
    for (let i = 0; i < input.length; ++i) {
      itemSerializer.encode(input[i]!, stream);
    }
  }

  decode(stream: InputStream): readonly Item[] {
    const wire = stream.readUint8();
    if (wire === 0 || wire === 246) {
      return _EMPTY_ARRAY;
    }
    const length = decodeArrayLength(wire, stream);
    const { itemSerializer } = this;
    const result = new Array<Item>(length);
    for (let i = 0; i < length; ++i) {
      result[i] = itemSerializer.decode(stream);
    }
    return freezeArray(result);
  }

  override isDefault(input: ReadonlyArray<Item>): boolean {
    return !input.length;
  }

  get itemType(): TypeDescriptor<Item> {
    return this.itemSerializer.typeDescriptor;
  }

  get typeSignature(): TypeSignature {
    return {
      kind: "array",
      value: {
        item: this.itemSerializer.typeSignature,
        key_extractor: this.keyExtractor,
      },
    };
  }

  addRecordDefinitionsTo(out: { [k: string]: RecordDefinition }): void {
    this.itemSerializer.addRecordDefinitionsTo(out);
  }
}

export class OptionalSerializerImpl<Other>
  extends AbstractSerializer<Other | null>
  implements OptionalDescriptor<Other | null>
{
  constructor(readonly otherSerializer: InternalSerializer<Other>) {
    super();
  }

  readonly kind = "optional";
  readonly defaultValue = null;

  toJson(input: Other, flavor?: JsonFlavor): Json {
    return input !== null ? this.otherSerializer.toJson(input, flavor) : null;
  }

  fromJson(json: Json, keep?: "keep-unrecognized-values"): Other | null {
    return json !== null ? this.otherSerializer.fromJson(json, keep) : null;
  }

  encode(input: Other | null, stream: OutputStream): void {
    if (input === null) {
      stream.writeUint8(255);
    } else {
      this.otherSerializer.encode(input, stream);
    }
  }

  decode(stream: InputStream): Other | null {
    const wire = stream.dataView.getUint8(stream.offset);
    if (wire === 255) {
      ++stream.offset;
      return null;
    }
    return this.otherSerializer.decode(stream);
  }

  override isDefault(input: Other | null): boolean {
    return input === null;
  }

  get otherType(): TypeDescriptor<NonNullable<Other>> {
    return this.otherSerializer.typeDescriptor as TypeDescriptor<
      NonNullable<Other>
    >;
  }

  get typeSignature(): TypeSignature {
    return {
      kind: "optional",
      value: this.otherSerializer.typeSignature,
    };
  }

  addRecordDefinitionsTo(out: { [k: string]: RecordDefinition }): void {
    this.otherSerializer.addRecordDefinitionsTo(out);
  }
}
