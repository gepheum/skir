import type { InputStream, OutputStream } from "../binary-io.js";
import {
  decodeArrayLength,
  decodeUint32,
  decodeUnused,
  encodeUint32,
} from "../binary-io.js";
import { ByteString } from "../byte-string.js";
import {
  _EnumBase,
  _FrozenBase,
  UnrecognizedEnum,
} from "../codegen-runtime/base.js";
import type {
  InternalSerializer,
  Json,
  JsonFlavor,
  MutableForm,
} from "./base.js";
import { AbstractSerializer } from "./base.js";
import type {
  EnumConstantVariant,
  EnumDefinition,
  EnumDescriptor,
  EnumVariantResult,
  RecordDefinition,
  StructDefinition,
  StructDescriptor,
  StructField,
  StructFieldResult,
  TypeDescriptor,
  TypeSignature,
} from "./type-descriptor.js";

export type AnyRecord = Record<string, unknown>;

export type NewMutableFn<Frozen> = (
  initializer?: Frozen | MutableForm<Frozen>,
) => MutableForm<Frozen>;

abstract class AbstractRecordSerializer<T, F> extends AbstractSerializer<T> {
  /** Uniquely identifies this record serializer. */
  readonly token: symbol = Symbol();
  abstract kind: "struct" | "enum";
  name = "";
  modulePath = "";
  parentType: StructDescriptor | EnumDescriptor | undefined;
  doc = "";
  removedNumbers = new Set<number>();
  initialized?: true;

  init(
    name: string,
    modulePath: string,
    parentType: StructDescriptor | EnumDescriptor | undefined,
    doc: string,
    fieldsOrVariants: readonly F[],
    removedNumbers: readonly number[],
  ): void {
    this.name = name;
    this.modulePath = modulePath;
    this.parentType = parentType;
    this.doc = doc;
    this.removedNumbers = new Set(removedNumbers);
    this.registerFieldsOrVariants(fieldsOrVariants);
    this.initialized = true;
    freezeDeeply(this);
  }

  get qualifiedName(): string {
    const { name, parentType } = this;
    return parentType ? `${parentType.name}.${name}` : name;
  }

  abstract registerFieldsOrVariants(fieldsOrVariants: readonly F[]): void;

  addRecordDefinitionsTo(out: { [k: string]: RecordDefinition }): void {
    const recordId = `${this.modulePath}:${this.qualifiedName}`;
    if (out[recordId]) {
      return;
    }
    const recordDefinition = this.makeRecordDefinition(recordId);
    if (this.doc) {
      recordDefinition.doc = this.doc;
    }
    if (this.removedNumbers.size) {
      recordDefinition.removed_numbers = [...this.removedNumbers];
    }
    out[recordId] = recordDefinition;
    for (const dependency of this.dependencies()) {
      dependency.addRecordDefinitionsTo(out);
    }
  }

  abstract makeRecordDefinition(recordId: string): RecordDefinition;
  abstract dependencies(): InternalSerializer[];
}

function freezeDeeply(o: unknown): void {
  if (!(o instanceof Object)) {
    return;
  }
  if (o instanceof _FrozenBase || o instanceof _EnumBase) {
    return;
  }
  if (o instanceof AbstractRecordSerializer && !o.initialized) {
    return;
  }
  if (Object.isFrozen(o)) {
    return;
  }
  Object.freeze(o);
  for (const v of Object.values(o)) {
    freezeDeeply(v);
  }
}

function copyJson(input: readonly Json[]): Json[];

function copyJson(input: Json): Json;

function copyJson(input: Json): Json {
  if (input instanceof Array) {
    return Object.freeze(input.map(copyJson));
  } else if (input instanceof Object) {
    return Object.freeze(
      Object.fromEntries(
        Object.entries(input).map(([k, v]) => [k, copyJson(v)]),
      ),
    );
  }
  // A boolean, a number, a string or null.
  return input;
}

export class StructFieldImpl<
  Struct = unknown,
  Value = unknown,
> implements StructField<Struct, Value> {
  constructor(
    readonly name: string,
    readonly property: string,
    readonly number: number,
    readonly serializer: InternalSerializer<Value>,
    readonly doc: string,
  ) {}

  get type(): TypeDescriptor<Value> {
    return this.serializer.typeDescriptor;
  }

  get(struct: Struct | MutableForm<Struct>): Value {
    return Reflect.get(struct as AnyRecord, this.property) as Value;
  }

  set(struct: MutableForm<Struct>, value: Value): void {
    Reflect.set(struct, this.property, value);
  }
}

/** Unrecognized fields found when deserializing a struct. */
class UnrecognizedFields {
  constructor(
    /** Uniquely identifies the struct. */
    readonly token: symbol,
    /** Total number of fields in the struct. */
    readonly totalSlots: number,
    readonly json?: ReadonlyArray<Json>,
    readonly bytes?: ByteString,
  ) {
    Object.freeze(this);
  }
}

export class StructSerializerImpl<T = unknown>
  extends AbstractRecordSerializer<T, StructFieldImpl<T>>
  implements StructDescriptor<T>
{
  constructor(
    readonly defaultValue: T,
    readonly createFn: (initializer: AnyRecord) => T,
    readonly newMutableFn: NewMutableFn<T>,
  ) {
    super();
  }

  readonly kind = "struct";
  // Fields in the order they appear in the '.skir' file.
  readonly fields: Array<StructFieldImpl<T>> = [];
  readonly fieldMapping: { [key: string | number]: StructFieldImpl<T> } = {};
  // Fields sorted by number in descending order.
  private reversedFields: Array<StructFieldImpl<T>> = [];
  // This is *not* a dense array, missing slots correspond to removed fields.
  private readonly slots: Array<StructFieldImpl<T>> = [];
  private recognizedSlots = 0;
  // Contains one zero for every field number.
  private readonly zeros: Json[] = [];
  private readonly initializerTemplate: Record<string, unknown> = {};

  toJson(input: T, flavor?: JsonFlavor): Json {
    if (input === this.defaultValue) {
      return flavor === "readable" ? {} : [];
    }
    const unrecognizedFields = (input as AnyRecord)["^"] as UnrecognizedFields;
    if (flavor === "readable") {
      const { fields } = this;
      const result: { [name: string]: Json } = {};
      for (const field of fields) {
        const { serializer } = field;
        const value = (input as AnyRecord)[field.property];
        if (field.serializer.isDefault(value)) {
          continue;
        }
        result[field.name] = serializer.toJson(value, flavor);
      }
      return result;
    } else {
      // Dense flavor.
      const { slots } = this;
      let result: Json[];
      if (unrecognizedFields?.token === this.token && unrecognizedFields.json) {
        // We'll need to copy the unrecognized fields to the JSON.
        result = this.zeros.concat(unrecognizedFields.json);
        for (const field of this.fields) {
          result[field.number] = field.serializer.toJson(
            (input as AnyRecord)[field.property],
            flavor,
          );
        }
      } else {
        result = [];
        const arrayLength = this.getArrayLength(input);
        for (let i = 0; i < arrayLength; ++i) {
          const field = slots[i];
          result[i] = field
            ? field.serializer.toJson(
                (input as AnyRecord)[field.property],
                flavor,
              )
            : 0;
        }
      }
      return result;
    }
  }

  fromJson(json: Json, keep?: "keep-unrecognized-values"): T {
    if (!json) {
      return this.defaultValue;
    }
    const initializer = { ...this.initializerTemplate };
    if (json instanceof Array) {
      const { slots, recognizedSlots } = this;
      // Dense flavor.
      if (json.length > recognizedSlots) {
        // We have some unrecognized fields.
        if (keep) {
          const unrecognizedFields = new UnrecognizedFields(
            this.token,
            json.length,
            copyJson(json.slice(recognizedSlots)),
          );
          initializer["^"] = unrecognizedFields;
        }
        // Now that we have stored the unrecognized fields in `initializer`, we
        // can remove them from `json`.
        json = json.slice(0, recognizedSlots);
      }
      for (let i = 0; i < json.length && i < slots.length; ++i) {
        const field = slots[i];
        if (field) {
          initializer[field.property] = field.serializer.fromJson(
            json[i]!,
            keep,
          );
        }
        // Else the field was removed.
      }
      return this.createFn(initializer);
    } else if (json instanceof Object) {
      // Readable flavor.
      const { fieldMapping } = this;
      for (const name in json) {
        const field = fieldMapping[name];
        if (field) {
          initializer[field.property] = field.serializer.fromJson(
            json[name]!,
            keep,
          );
        } else if (keep) {
          throw new Error(
            `Cannot keep unrecognized readable struct field: ${name}`,
          );
        }
      }
      return this.createFn(initializer);
    }
    throw TypeError();
  }

  encode(input: T, stream: OutputStream): void {
    // Total number of slots to write. Includes removed and unrecognized fields.
    let totalSlots: number;
    let recognizedSlots: number;
    let unrecognizedBytes: ByteString | undefined;
    const unrecognizedFields = (input as AnyRecord)["^"] as UnrecognizedFields;
    if (unrecognizedFields?.token === this.token && unrecognizedFields.bytes) {
      totalSlots = unrecognizedFields.totalSlots;
      recognizedSlots = this.recognizedSlots;
      unrecognizedBytes = unrecognizedFields.bytes;
    } else {
      // No unrecognized fields.
      totalSlots = recognizedSlots = this.getArrayLength(input);
    }

    if (totalSlots <= 3) {
      stream.writeUint8(246 + totalSlots);
    } else {
      stream.writeUint8(250);
      encodeUint32(totalSlots, stream);
    }
    const { slots } = this;
    for (let i = 0; i < recognizedSlots; ++i) {
      const field = slots[i];
      if (field) {
        field.serializer.encode((input as AnyRecord)[field.property], stream);
      } else {
        // Append '0' if the field was removed.
        stream.writeUint8(0);
      }
    }
    if (unrecognizedBytes) {
      // Copy the unrecognized fields.
      stream.putBytes(unrecognizedBytes);
    }
  }

  decode(stream: InputStream): T {
    const wire = stream.readUint8();
    if (wire === 0 || wire === 246) {
      return this.defaultValue;
    }
    const initializer = { ...this.initializerTemplate };
    const encodedSlots = decodeArrayLength(wire, stream);
    const { slots, recognizedSlots } = this;
    // Do not read more slots than the number of recognized slots.
    for (let i = 0; i < encodedSlots && i < recognizedSlots; ++i) {
      const field = slots[i];
      if (field) {
        initializer[field.property] = field.serializer.decode(stream);
      } else {
        // The field was removed.
        decodeUnused(stream);
      }
    }
    if (encodedSlots > recognizedSlots) {
      // We have some unrecognized fields.
      const start = stream.offset;
      for (let i = recognizedSlots; i < encodedSlots; ++i) {
        decodeUnused(stream);
      }
      if (stream.keepUnrecognizedValues) {
        const end = stream.offset;
        const unrecognizedBytes = ByteString.sliceOf(stream.buffer, start, end);
        const unrecognizedFields = new UnrecognizedFields(
          this.token,
          encodedSlots,
          undefined,
          unrecognizedBytes,
        );
        initializer["^"] = unrecognizedFields;
      }
    }
    return this.createFn(initializer);
  }

  /**
   * Returns the length of the JSON array for the given input, which is also the
   * number of slots and includes removed fields.
   * Assumes that `input` does not contain unrecognized fields.
   */
  private getArrayLength(input: T): number {
    const { reversedFields } = this;
    for (let i = 0; i < reversedFields.length; ++i) {
      const field = reversedFields[i]!;
      const isDefault = //
        field.serializer.isDefault((input as AnyRecord)[field.property]);
      if (!isDefault) {
        return field.number + 1;
      }
    }
    return 0;
  }

  override isDefault(input: T): boolean {
    if (input === this.defaultValue) {
      return true;
    }
    // It's possible for a value of type T to be equal to T.DEFAULT but to not
    // be the reference to T.DEFAULT.
    if ((input as AnyRecord)["^"] as UnrecognizedFields) {
      return false;
    }
    return this.fields.every((f) =>
      f.serializer.isDefault((input as AnyRecord)[f.property]),
    );
  }

  get typeSignature(): TypeSignature {
    return {
      kind: "record",
      value: `${this.modulePath}:${this.qualifiedName}`,
    };
  }

  getField<K extends string | number>(key: K): StructFieldResult<T, K> {
    return this.fieldMapping[key]!;
  }

  newMutable(initializer?: T | MutableForm<T>): MutableForm<T> {
    return this.newMutableFn(initializer);
  }

  registerFieldsOrVariants(fields: ReadonlyArray<StructFieldImpl<T>>): void {
    for (const field of fields) {
      const { name, number, property } = field;
      this.fields.push(field);
      this.slots[number] = field;
      this.fieldMapping[name] = field;
      this.fieldMapping[property] = field;
      this.fieldMapping[number] = field;
      this.initializerTemplate[property] = (this.defaultValue as AnyRecord)[
        field.property
      ];
    }
    // Removed numbers count as recognized slots.
    this.recognizedSlots =
      Math.max(this.slots.length - 1, ...this.removedNumbers) + 1;
    this.zeros.push(...Array<Json>(this.recognizedSlots).fill(0));
    this.reversedFields = [...this.fields].sort((a, b) => b.number - a.number);
  }

  makeRecordDefinition(recordId: string): StructDefinition {
    return {
      kind: "struct",
      id: recordId,
      doc: undefined,
      fields: this.fields.map((f) => ({
        name: f.name,
        number: f.number,
        type: f.serializer.typeSignature,
        doc: f.doc || undefined,
      })),
    };
  }

  dependencies(): InternalSerializer[] {
    return this.fields.map((f) => f.serializer);
  }
}

type EnumVariantImpl<Enum = unknown> =
  EnumConstantVariantImpl<Enum> | EnumWrapperVariantImpl<Enum, unknown>;

interface EnumConstantVariantImpl<Enum> extends EnumConstantVariant<Enum> {
  readonly serializer?: undefined;
}

export class EnumWrapperVariantImpl<Enum, Value = unknown> {
  constructor(
    readonly name: string,
    readonly number: number,
    readonly serializer: InternalSerializer<Value>,
    readonly doc: string,
    private createFn: (initializer: { kind: string; value: unknown }) => Enum,
  ) {}

  get type(): TypeDescriptor<Value> {
    return this.serializer.typeDescriptor;
  }

  readonly constant?: undefined;

  get(e: Enum): Value | undefined {
    return (e as AnyRecord).kind === this.name
      ? ((e as AnyRecord).value as Value)
      : undefined;
  }

  wrap(value: Value): Enum {
    return this.createFn({ kind: this.name, value: value });
  }
}

export class EnumSerializerImpl<T = unknown>
  extends AbstractRecordSerializer<T, EnumVariantImpl<T>>
  implements EnumDescriptor<T>
{
  constructor(readonly createFn: (initializer: unknown) => T) {
    super();
    this.defaultValue = createFn("UNKNOWN");
  }

  readonly kind = "enum";
  readonly defaultValue: T;
  readonly variants: EnumVariantImpl<T>[] = [];
  private readonly variantMapping: {
    [key: string | number]: EnumVariantImpl<T>;
  } = {};

  toJson(input: T, flavor?: JsonFlavor): Json {
    const unrecognized = (input as AnyRecord)["^"] as
      UnrecognizedEnum | undefined;
    const kind = (input as AnyRecord).kind as string;
    if (
      kind === "UNKNOWN" &&
      unrecognized?.token === this.token &&
      unrecognized.json !== undefined
    ) {
      // Unrecognized variant.
      return unrecognized.json;
    }
    if (kind === "UNKNOWN") {
      return flavor === "readable" ? "unknown" : 0;
    }
    const variant = this.variantMapping[kind]!;
    const { serializer } = variant;
    if (serializer) {
      const value = (input as AnyRecord).value;
      if (flavor === "readable") {
        return {
          kind: variant.name,
          value: serializer.toJson(value, flavor),
        };
      } else {
        // Dense flavor.
        return [variant.number, serializer.toJson(value, flavor)];
      }
    } else {
      // A constant variant.
      return flavor === "readable"
        ? variant.name.toLowerCase()
        : variant.number;
    }
  }

  fromJson(json: Json, keep?: "keep-unrecognized-values"): T {
    const isNumber = typeof json === "number";
    if (isNumber || typeof json === "string") {
      const variant = this.variantMapping[isNumber ? json : String(json)];
      if (!variant) {
        // Check if the variant was removed, in which case we want to return
        // UNKNOWN, or is unrecognized.
        return !keep || (isNumber && this.removedNumbers.has(json))
          ? this.defaultValue
          : this.createFn(new UnrecognizedEnum(this.token, copyJson(json)));
      }
      if (variant.serializer) {
        // A constant variant became a wrapper variant.
        return variant.wrap(variant.serializer.defaultValue);
      }
      return variant.constant;
    }
    let variantKey: number | string;
    let valueAsJson: Json;
    if (json instanceof Array) {
      variantKey = json[0] as number;
      valueAsJson = json[1]!;
    } else if (json instanceof Object) {
      variantKey = json["kind"] as string;
      valueAsJson = json["value"]!;
    } else {
      throw TypeError();
    }
    const variant = this.variantMapping[variantKey];
    if (!variant) {
      // Check if the variant was removed, in which case we want to return
      // UNKNOWN, or is unrecognized.
      return !keep ||
        (typeof variantKey === "number" && this.removedNumbers.has(variantKey))
        ? this.defaultValue
        : this.createFn(
            new UnrecognizedEnum(this.token, copyJson(json), undefined),
          );
    }
    const { serializer } = variant;
    if (!serializer) {
      // A wrapper variant became a constant variant.
      return variant.constant;
    }
    return variant.wrap(serializer.fromJson(valueAsJson, keep));
  }

  encode(input: T, stream: OutputStream): void {
    const unrecognized = //
      (input as AnyRecord)["^"] as UnrecognizedEnum | undefined;
    const kind = (input as AnyRecord).kind as string;
    if (
      kind === "UNKNOWN" &&
      unrecognized?.token === this.token &&
      unrecognized.bytes
    ) {
      // Unrecognized variant.
      stream.putBytes(unrecognized.bytes);
      return;
    }
    if (kind === "UNKNOWN") {
      stream.writeUint8(0);
      return;
    }
    const variant = this.variantMapping[kind]!;
    const { number, serializer } = variant;
    if (serializer) {
      // A wrapper variant.
      const value = (input as AnyRecord).value;
      if (number < 5) {
        // The number can't be 0 or else kind == "UNKNOWN".
        stream.writeUint8(250 + number);
      } else {
        stream.writeUint8(248);
        encodeUint32(number, stream);
      }
      serializer.encode(value, stream);
    } else {
      // A constant variant.
      encodeUint32(number, stream);
    }
  }

  decode(stream: InputStream): T {
    const startOffset = stream.offset;
    const wire = stream.dataView.getUint8(startOffset);
    if (wire < 242) {
      // A number
      const number = decodeUint32(stream);
      const variant = this.variantMapping[number];
      if (!variant) {
        // Check if the variant was removed, in which case we want to return
        // UNKNOWN, or is unrecognized.
        if (!stream.keepUnrecognizedValues || this.removedNumbers.has(number)) {
          return this.defaultValue;
        } else {
          const { offset } = stream;
          const bytes = ByteString.sliceOf(stream.buffer, startOffset, offset);
          return this.createFn(
            new UnrecognizedEnum(this.token, undefined, bytes),
          );
        }
      }
      if (variant.serializer) {
        // A constant variant became a wrapper variant.
        return variant.wrap(variant.serializer.defaultValue);
      }
      return variant.constant;
    } else {
      if (wire !== 248 && (wire < 251 || wire > 254)) {
        throw new Error(`Invalid enum wire tag: ${wire}`);
      }
      ++stream.offset;
      const number = wire === 248 ? decodeUint32(stream) : wire - 250;
      const variant = this.variantMapping[number];
      if (!variant) {
        decodeUnused(stream);
        // Check if the variant was removed, in which case we want to return
        // UNKNOWN, or is unrecognized.
        if (!stream.keepUnrecognizedValues || this.removedNumbers.has(number)) {
          return this.defaultValue;
        } else {
          const { offset } = stream;
          const bytes = ByteString.sliceOf(stream.buffer, startOffset, offset);
          return this.createFn(
            new UnrecognizedEnum(this.token, undefined, bytes),
          );
        }
      }
      const { serializer } = variant;
      if (!serializer) {
        decodeUnused(stream);
        // A wrapper variant became a constant variant.
        return variant.constant;
      }
      return variant.wrap(serializer.decode(stream));
    }
  }

  get typeSignature(): TypeSignature {
    return {
      kind: "record",
      value: `${this.modulePath}:${this.qualifiedName}`,
    };
  }

  override isDefault(input: T): boolean {
    type Kinded = { kind: string };
    return (input as Kinded).kind === "UNKNOWN" && !(input as AnyRecord)["^"];
  }

  getVariant<K extends string | number>(key: K): EnumVariantResult<T, K> {
    return this.variantMapping[key]!;
  }

  registerFieldsOrVariants(variants: ReadonlyArray<EnumVariantImpl<T>>): void {
    for (const variant of variants) {
      this.variants.push(variant);
      this.variantMapping[variant.name] = variant;
      // Register case aliases for constant variants so that both UPPER_CASE
      // and lower_case names are accepted when parsing readable JSON.
      if (variant.serializer === undefined) {
        const nameUpper = variant.name.toUpperCase();
        if (nameUpper !== variant.name) {
          this.variantMapping[nameUpper] = variant;
        }
        const nameLower = variant.name.toLowerCase();
        if (nameLower !== variant.name) {
          this.variantMapping[nameLower] = variant;
        }
      }
      this.variantMapping[variant.number] = variant;
    }
  }

  makeRecordDefinition(recordId: string): EnumDefinition {
    return {
      kind: "enum",
      id: recordId,
      doc: undefined,
      variants: this.variants
        // Skip the UNKNOWN variant.
        .filter((f) => f.number)
        .map((f) => {
          const result = {
            name: f.name.toLowerCase(),
            number: f.number,
            doc: f.doc || undefined,
          };
          const type = f?.serializer?.typeSignature;
          return type ? { ...result, type: type } : result;
        }),
    };
  }

  dependencies(): InternalSerializer[] {
    const result: InternalSerializer[] = [];
    for (const f of this.variants) {
      if (f.serializer) {
        result.push(f.serializer);
      }
    }
    return result;
  }
}
