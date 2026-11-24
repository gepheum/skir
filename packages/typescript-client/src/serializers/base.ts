import type { BinaryForm } from "../binary-io.js";
import { InputStream, OutputStream } from "../binary-io.js";
import type { _FrozenBase } from "../codegen-runtime/base.js";
import type {
  RecordDefinition,
  TypeDefinition,
  TypeDescriptorSpecialization,
  TypeSignature,
} from "./type-descriptor.js";

/**
 * Resolves to the generated mutable class for a struct.
 * The type parameter is the generated frozen class.
 */
export type MutableForm<Frozen> =
  //
  Frozen extends _FrozenBase
    ? ReturnType<Frozen["toMutable"]> & Freezable<Frozen>
    : Freezable<Frozen>;

/** A read-only JSON value. */
export type Json =
  | null
  | boolean
  | number
  | string
  | readonly Json[]
  | Readonly<{ [name: string]: Json }>;

/**
 * When using the JSON serialization format, you can chose between two flavors.
 *
 * The dense flavor is the default flavor and is preferred in most cases.
 * Structs are converted to JSON arrays, where the number of each field
 * corresponds to the index of the value in the array. This results in a more
 * compact representation than when using JSON objects, and this makes
 * serialization and deserialization a bit faster. Because field names are left
 * out of the JSON, it is a representation which allows persistence: you can
 * safely rename a field in a '.skir' file without breaking backwards
 * compatibility.
 * One con of this representation is that it is harder to tell, just by looking
 * at the JSON, what field of the struct each value in the array corresponds to.
 *
 * When using the readable flavor, structs are converted to JSON objects. The
 * name of each field in the '.skir' file is used as-is in the JSON. This
 * results in a representation which is much more readable by humans, but also
 * not suited for persistence: when you rename a field in a '.skir' file, you
 * will no lonnger be able to deserialize old JSONs.
 *
 * @example
 * const jane = Person.create({firstName: "Jane", lastName: "Doe"});
 *
 * console.log(Person.serializer.toJson(jane, "dense"));
 * // Output: ["Jane","Doe"]
 *
 * console.log(Person.serializer.toJson(jane));
 * // Output: ["Jane","Doe"]
 *
 * console.log(Person.serializer.toJson(jane, "readable"));
 * // Output: {
 * //   "firstName": "Jane",
 * //   "lastName": "Doe"
 * // }
 */
export type JsonFlavor = "dense" | "readable";

/**
 * Serializes and deserializes instances of `T`. Supports two serialization
 * formats: JSON and binary.
 *
 * All deserialization methods return a deeply-immutable `T`. If `T` is the
 * generated frozen class for a struct, all serialization methods accept either
 * a `T` or a `T.Mutable`.
 *
 * Do NOT create your own `Serializer` implementation. Only use implementations
 * provided by Skir.
 *
 * @example
 * let jane = Person.create({firstName: "Jane", lastName: "Doe"});
 * const json = Person.serializer.toJson(jane);
 * jane = Person.serializer.fromJson(json);
 * expect(jane.firstName).toBe("Jane");
 */
export interface Serializer<T> {
  /**
   * Converts back the given stringified JSON to `T`.
   * Works with both [flavors]{@link JsonFlavor} of JSON.
   *
   * Pass in "keep-unrecognized-values" if and only if the input JSON comes
   * from a trusted program which might have been built from more recent
   * source files.
   */
  fromJsonCode(code: string, keep?: "keep-unrecognized-values"): T;
  /**
   * Converts back the given JSON to `T`.
   * Works with both [flavors]{@link JsonFlavor} of JSON.
   *
   * Pass in "keep-unrecognized-values" if and only if the input JSON comes
   * from a trusted program which might have been built from more recent
   * source files.
   */
  fromJson(json: Json, keep?: "keep-unrecognized-values"): T;
  /**
   * Converts back the given binary form to `T`.
   *
   * Pass in "keep-unrecognized-values" if and only if the input JSON comes
   * from a trusted program which might have been built from more recent
   * source files.
   */
  fromBytes(bytes: ArrayBuffer, keep?: "keep-unrecognized-values"): T;
  /**
   * Converts the given `T` to JSON and returns the stringified JSON. Same as
   * calling `JSON.stringify()` on the result of `toJson()`.
   *
   * @param flavor dense or readable, defaults to dense
   * @see JsonFlavor
   */
  toJsonCode(input: T | MutableForm<T>, flavor?: JsonFlavor): string;
  /**
   * Converts the given `T` to JSON. If you only need the stringified JSON, call
   * `toJsonCode()` instead.
   *
   * @param flavor dense or readable, defaults to dense
   * @see JsonFlavor
   */
  toJson(input: T | MutableForm<T>, flavor?: JsonFlavor): Json;
  /** Converts the given `T` to binary format. */
  toBytes(input: T | MutableForm<T>): BinaryForm;
  /** An object describing the type `T`. Enables reflective programming. */
  typeDescriptor: TypeDescriptorSpecialization<T>;
}

/**
 * Interface implemented by both the frozen and mutable classes generated for a
 * struct. `T` is always the generated frozen class.
 */
export interface Freezable<T> {
  /**
   * Returns a deeply-immutable object, either by making a copy of `this` if
   * `this` is mutable, or by returning `this` as-is if `this` is already
   * immutable.
   */
  toFrozen(): T;
}

export interface InternalSerializer<T = unknown> extends Serializer<T> {
  readonly defaultValue: T;
  isDefault(input: T): boolean;
  decode(stream: InputStream): T;
  encode(input: T, stream: OutputStream): void;
  readonly typeSignature: TypeSignature;
  addRecordDefinitionsTo(out: { [k: string]: RecordDefinition }): void;
}

export abstract class AbstractSerializer<T> implements InternalSerializer<T> {
  fromJsonCode(code: string, keep?: "keep-unrecognized-values"): T {
    return this.fromJson(JSON.parse(code), keep);
  }

  fromBytes(bytes: ArrayBuffer, keep?: "keep-unrecognized-values"): T {
    const inputStream = new InputStream(bytes, keep);
    if (
      bytes.byteLength < 4 ||
      inputStream.dataView.getUint32(0) !== 0x736b6972
    ) {
      throw new Error("Invalid skir binary header");
    }
    inputStream.offset = 4; // Skip the "skir" header.
    const value = this.decode(inputStream);
    if (inputStream.offset !== bytes.byteLength) {
      throw new Error("Trailing or truncated binary data");
    }
    return value;
  }

  toJsonCode(input: T, flavor?: JsonFlavor): string {
    const indent = flavor === "readable" ? "  " : undefined;
    return JSON.stringify(this.toJson(input, flavor), undefined, indent);
  }

  toBytes(input: T): BinaryForm {
    const stream = new OutputStream();
    stream.putUtf8String("skir");
    this.encode(input, stream);
    return stream.finalize();
  }

  // Default implementation; this behavior is not correct for all subclasses.
  isDefault(input: T): boolean {
    return !input;
  }

  get typeDescriptor(): TypeDescriptorSpecialization<T> {
    return this as unknown as TypeDescriptorSpecialization<T>;
  }

  abstract readonly defaultValue: T;
  abstract fromJson(json: Json, keep?: "keep-unrecognized-values"): T;
  abstract toJson(input: T, flavor?: JsonFlavor): Json;
  abstract decode(stream: InputStream): T;
  abstract encode(input: T, stream: OutputStream): void;

  abstract readonly typeSignature: TypeSignature;
  abstract addRecordDefinitionsTo(out: { [k: string]: RecordDefinition }): void;

  asJson(): Json {
    const recordDefinitions: { [k: string]: RecordDefinition } = {};
    this.addRecordDefinitionsTo(recordDefinitions);
    const result: TypeDefinition = {
      type: this.typeSignature,
      records: Object.values(recordDefinitions),
    };
    return result;
  }

  asJsonCode(): string {
    return JSON.stringify(this.asJson(), undefined, "  ");
  }

  transform(json_or_bytes: Json | ArrayBuffer, out: JsonFlavor): Json;
  transform(json: Json, out: "bytes"): ArrayBuffer;
  transform(
    json_or_bytes: Json | ArrayBuffer,
    out: JsonFlavor | "bytes",
  ): Json | ArrayBuffer {
    const decoded: T =
      json_or_bytes instanceof ArrayBuffer
        ? this.fromBytes(json_or_bytes, "keep-unrecognized-values")
        : this.fromJson(json_or_bytes, "keep-unrecognized-values");
    return out === "bytes"
      ? this.toBytes(decoded).toBuffer()
      : this.toJson(decoded, out);
  }
}
