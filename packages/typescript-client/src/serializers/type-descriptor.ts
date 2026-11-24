import type { ByteString } from "../byte-string.js";
import type {
  _EnumBase,
  _FrozenBase,
  _INITIALIZER,
} from "../codegen-runtime/base.js";
import { UnrecognizedEnum } from "../codegen-runtime/base.js";
import type { Timestamp } from "../timestamp.js";
import type {
  InternalSerializer,
  Json,
  JsonFlavor,
  MutableForm,
} from "./base.js";
import { ArraySerializerImpl, OptionalSerializerImpl } from "./collections.js";
import { primitiveSerializer } from "./primitives.js";
import type { AnyRecord, NewMutableFn } from "./records.js";
import {
  EnumSerializerImpl,
  EnumWrapperVariantImpl,
  StructFieldImpl,
  StructSerializerImpl,
} from "./records.js";

/**
 * Describes the type `T`, where `T` is the TypeScript equivalent of a Skir
 * type. Enables reflective programming.
 *
 * Every `TypeDescriptor` instance has a `kind` field which can take one of
 * these 5 values: `"primitive"`, `"optional"`, `"array"`, `"struct"`, `"enum"`.
 */
export type TypeDescriptor<T = unknown> =
  | OptionalDescriptor<T>
  | ArrayDescriptor<T>
  | StructDescriptor<T>
  | EnumDescriptor<T>
  | PrimitiveDescriptor;

/** Specialization of `TypeDescriptor<T>` when `T` is known. */
export type TypeDescriptorSpecialization<T> =
  //
  [T] extends [_FrozenBase]
    ? StructDescriptor<T>
    : [T] extends [_EnumBase]
      ? EnumDescriptor<T>
      : TypeDescriptor<T>;

interface TypeDescriptorBase {
  /** Returns the JSON representation of this `TypeDescriptor`. */
  asJson(): Json;

  /**
   * Returns the JSON code representation of this `TypeDescriptor`.
   * Same as calling `JSON.stringify()` on the result of `asJson()`.
   */
  asJsonCode(): string;

  /**
   * Converts from one serialized form to another.
   *
   * @example
   * const denseJson = User.serializer.toJson(user, "dense");
   * expect(
   *   User.serializer.typeDescriptor.transform(denseJson, "readable")
   * ).toMatch(
   *   User.serializer.toJson(user, "readable")
   * );
   */
  transform(json_or_bytes: Json | ArrayBuffer, out: JsonFlavor): Json;
  transform(json: Json, out: "bytes"): ArrayBuffer;
  transform(
    json_or_bytes: Json | ArrayBuffer,
    out: JsonFlavor | "bytes",
  ): Json | ArrayBuffer;
}

/** Describes a primitive Skir type. */
export interface PrimitiveDescriptor extends TypeDescriptorBase {
  kind: "primitive";
  primitive: keyof PrimitiveTypes;
}

/**
 * An interface mapping a primitive Skir type to the corresponding TypeScript
 * type.
 */
export interface PrimitiveTypes {
  bool: boolean;
  int32: number;
  int64: bigint;
  hash64: bigint;
  float32: number;
  float64: number;
  timestamp: Timestamp;
  string: string;
  bytes: ByteString;
}

/**
 * Describes an optional type. In a '.skir' file, an optional type is
 * represented with a question mark at the end of another type.
 */
export interface OptionalDescriptor<T> extends TypeDescriptorBase {
  readonly kind: "optional";
  /** Describes the other (non-optional) type. */
  readonly otherType: TypeDescriptor<NonNullable<T>>;
}

/** Describes an array type. */
export interface ArrayDescriptor<T> extends TypeDescriptorBase {
  readonly kind: "array";
  /** Describes the type of the array items. */
  readonly itemType: TypeDescriptor<
    T extends ReadonlyArray<infer Item> ? Item : unknown
  >;
  readonly keyChain?: string;
}

/**
 * Describes a Skir struct.
 * The type parameter `T` refers to the generated frozen class for the struct.
 */
export interface StructDescriptor<T = unknown> extends TypeDescriptorBase {
  readonly kind: "struct";
  /** Name of the struct as specified in the '.skir' file. */
  readonly name: string;
  /**
   * A string containing all the names in the hierarchic sequence above and
   * including the struct. For example: "Foo.Bar" if "Bar" is nested within a
   * type called "Foo", or simply "Bar" if "Bar" is defined at the top-level of
   * the module.
   */
  readonly qualifiedName: string;
  /**
   * Path to the module where the struct is defined, relative to the root of the
   * project.
   */
  readonly modulePath: string;
  /**
   * If the struct is nested within another type, the descriptor for that type.
   * Undefined if the struct is defined at the top-level of the module.
   */
  readonly parentType: StructDescriptor | EnumDescriptor | undefined;
  /** The fields of the struct in the order they appear in the '.skir' file. */
  readonly fields: ReadonlyArray<StructField<T>>;
  /** The field numbers marked as removed. */
  readonly removedNumbers: ReadonlySet<number>;

  /**
   * Looks up a field. The key can be one of: the field name (e.g. "user_id");
   * the name of the property in the generated class (e.g. "userId"), the field
   * number.
   *
   * The return type is `StructField<T> | undefined` unless the key is known at
   * compile-time to be the name of the property in the generated class, in
   * which case it is `StructField<T>`.
   */
  getField<K extends string | number>(key: K): StructFieldResult<T, K>;

  /**
   * Returns a new instance of the generated mutable class for a struct.
   * Performs a shallow copy of `initializer` if `initializer` is specified.
   */
  newMutable(initializer?: T | MutableForm<T>): MutableForm<T>;
}

/** Field of a Skir struct. */
export interface StructField<Struct = unknown, Value = unknown> {
  /** Field name as specified in the '.skir' file, e.g. "user_id". */
  readonly name: string;
  /** Name of the property in the generated class, e.g. "userId". */
  readonly property: string;
  /** Field number. */
  readonly number: number;
  /** Describes the field type. */
  readonly type: TypeDescriptor<Value>;
  /**
   * Documentation for this struct field, specified as doc comments in the
   * '.skir' file. May be empty.
   */
  doc: string;

  /** Extracts the value of the field from the given struct. */
  get(struct: Struct | MutableForm<Struct>): Value;
  /** Assigns the given value to the field of the given struct. */
  set(struct: MutableForm<Struct>, value: Value): void;
}

/**
 * Return type of the `StructDescriptor.getField` method. If the argument is
 * known at compile-time to be the name of a property of the generated class,
 * resolves to `StructField<Struct>`. Otherwise, resolves to
 * `StructField<Struct> | undefined`.
 *
 * @example <caption>The field is kown at compile-time</caption>
 * const fieldNumber: number =
 *   User.serializer.typeDescriptor.getField("userId").number;
 *
 * @example <caption>The field is not kown at compile-time</caption>
 * const fieldNumber: number | undefined =
 *   User.serializer.typeDescriptor.getField(variable)?.number;
 */
export type StructFieldResult<Struct, Key extends string | number> =
  | StructField<Struct>
  | (Struct extends _FrozenBase
      ? Key extends keyof NonNullable<Struct[typeof _INITIALIZER]>
        ? never
        : undefined
      : undefined);

/** Describes a Skir enum. */
export interface EnumDescriptor<T = unknown> extends TypeDescriptorBase {
  readonly kind: "enum";
  /** Name of the enum as specified in the '.skir' file. */
  readonly name: string;
  /**
   * A string containing all the names in the hierarchic sequence above and
   * including the enum. For example: "Foo.Bar" if "Bar" is nested within a type
   * called "Foo", or simply "Bar" if "Bar" is defined at the top-level of the
   * module.
   */
  readonly qualifiedName: string;
  /**
   * Path to the module where the enum is defined, relative to the root of the
   * project.
   */
  readonly modulePath: string;
  /**
   * If the enum is nested within another type, the descriptor for that type.
   * Undefined if the struct is defined at the top-level of the module.
   */
  readonly parentType: StructDescriptor | EnumDescriptor | undefined;
  /**
   * Includes the UNKNOWN variant, followed by the other variants in the order
   * they appear in the '.skir' file.
   */
  readonly variants: ReadonlyArray<EnumVariant<T>>;
  /** The variant numbers marked as removed. */
  readonly removedNumbers: ReadonlySet<number>;

  /**
   * Looks up a variant. The key can be one of the variant name or the variant
   * number.
   *
   * The return type is `EnumVariant<T> | undefined` unless the key is known at
   * compile-time to be a variant name of the enum, in which case it is
   * `EnumVariant<T>`.
   */
  getVariant<K extends string | number>(key: K): EnumVariantResult<T, K>;
}

/**
 * Variant of a Skir enum. Variants which don't hold any value are called
 * constant variants. Their name is always in UPPER_CASE. Variants which hold
 * value of a given type are called wrapper variants, and their name is always
 * in lower_case.
 */
export type EnumVariant<Enum = unknown> =
  EnumConstantVariant<Enum> | EnumWrapperVariant<Enum, unknown>;

/** Constant variant of a Skir enum. */
export interface EnumConstantVariant<Enum = unknown> {
  /**
   * Variant name as specified in the '.skir' file, e.g. "MONDAY".
   * Always in UPPER_CASE format.
   */
  readonly name: string;
  /** Variant number. */
  readonly number: number;
  /** The instance of the generated class which corresponds to this variant. */
  readonly constant: Enum;
  /** Always undefined, unlike the `type` field of `EnumWrapperVariant`. */
  readonly type?: undefined;
  /**
   * Documentation for this enum variant, specified as doc comments in the
   * '.skir' file. May be empty.
   */
  readonly doc: string;
}

/** Wrapper variant of a Skir enum. */
export interface EnumWrapperVariant<Enum = unknown, Value = unknown> {
  /**
   * Variant name as specified in the '.skir' file, e.g. "v4".
   * Always in lower_case format.
   */
  readonly name: string;
  /** Variant number. */
  readonly number: number;
  /** Describes the type of the value held by the variant. */
  readonly type: TypeDescriptor<Value>;
  /** Always undefined, unlike the `type` field of `EnumConstantVariant`. */
  readonly constant?: undefined;
  /**
   * Documentation for this enum variant, specified as doc comments in the
   * '.skir' file. May be empty.
   */
  readonly doc: string;

  /**
   * Extracts the value held by the given enum instance if it matches this
   * enum variant. Returns undefined otherwise.
   */
  get(e: Enum): Value | unknown;
  /**
   * Returns a new enum instance matching this enum variant and holding the
   * given value.
   */
  wrap(value: Value): Enum;
}

/**
 * Return type of the `EnumDescriptor.getVariant` method. If the argument is
 * known at compile-time to be the name of variant, resolves to
 * `EnumVariant<Enum>`. Otherwise, resolves to
 * `EnumVariant<Struct> | undefined`.
 *
 * @example <caption>The variant is known at compile-time</caption>
 * const variantNumber: number =
 *   Weekday.serializer.typeDescriptor.getVariant("MONDAY").number;
 *
 * @example <caption>The variant is not known at compile-time</caption>
 * const variantNumber: number | undefined =
 *   Weekday.serializer.typeDescriptor.getVariant(variable)?.number;
 */
export type EnumVariantResult<Enum, Key extends string | number> =
  | EnumVariant<Enum>
  | (Enum extends _EnumBase
      ? Key extends Enum["union"]["kind"]
        ? never
        : undefined
      : undefined);

/** JSON representation of a `TypeDescriptor`. */
export type TypeDefinition = {
  type: TypeSignature;
  records: readonly RecordDefinition[];
};

/** A type in the JSON representation of a `TypeDescriptor`. */
export type TypeSignature =
  | {
      kind: "optional";
      value: TypeSignature;
    }
  | {
      kind: "array";
      value: {
        item: TypeSignature;
        key_extractor?: string;
      };
    }
  | {
      kind: "record";
      value: string;
    }
  | {
      kind: "primitive";
      value: keyof PrimitiveTypes;
    };

/**
 * Definition of a struct field in the JSON representation of a
 * `TypeDescriptor`.
 */
export type FieldDefinition = {
  name: string;
  type: TypeSignature;
  number: number;
  doc?: string;
};

/**
 * Definition of an enum variant in the JSON representation of a
 * `TypeDescriptor`.
 */
export type VariantDefinition = {
  name: string;
  type?: TypeSignature;
  number: number;
  doc?: string;
};

/** Definition of a struct in the JSON representation of a `TypeDescriptor`. */
export type StructDefinition = {
  kind: "struct";
  id: string;
  doc?: string;
  fields: readonly FieldDefinition[];
  removed_numbers?: readonly number[];
};

/** Definition of an enum in the JSON representation of a `TypeDescriptor`. */
export type EnumDefinition = {
  kind: "enum";
  id: string;
  doc?: string;
  variants: readonly VariantDefinition[];
  removed_numbers?: readonly number[];
};

export type RecordDefinition = StructDefinition | EnumDefinition;

// The UNKNOWN variant is common to all enums.
const UNKNOWN_VARIANT_DEFINITION: VariantDefinition = {
  name: "UNKNOWN",
  number: 0,
};

/**
 * Returns a `TypeDescriptor` from its JSON representation as returned by
 * `asJson()`.
 */
export function parseTypeDescriptorFromJson(json: Json): TypeDescriptor {
  const typeDefinition = json as TypeDefinition;

  type RecordBundle = {
    readonly definition: RecordDefinition;
    readonly serializer: StructSerializerImpl<Json> | EnumSerializerImpl<Json>;
  };
  const recordBundles: { [k: string]: RecordBundle } = {};

  // First loop: create the serializer for each record.
  // It's not yet initialized.
  for (const record of typeDefinition.records) {
    let serializer: StructSerializerImpl<Json> | EnumSerializerImpl<Json>;
    switch (record.kind) {
      case "struct":
        serializer = new StructSerializerImpl<Json>(
          {},
          (initializer: AnyRecord) => Object.freeze({ ...initializer }) as Json,
          (() => ({})) as NewMutableFn<Json>,
        );
        break;
      case "enum":
        serializer = new EnumSerializerImpl<Json>((o: unknown) => {
          if (o instanceof UnrecognizedEnum) {
            return Object.freeze({
              kind: "UNKNOWN",
              "^": o,
            }) as unknown as Json;
          }
          if (typeof o === "string") {
            return Object.freeze({ kind: o }) as Json;
          } else {
            const kind = (o as AnyRecord).kind;
            const value = (o as AnyRecord).value;
            const ret = { kind, value } as Json;
            return Object.freeze(ret);
          }
        });
        break;
    }
    const recordBundle: RecordBundle = {
      definition: record,
      serializer: serializer,
    };
    recordBundles[record.id] = recordBundle;
  }

  function parse(ts: TypeSignature): InternalSerializer {
    switch (ts.kind) {
      case "array": {
        const { item, key_extractor } = ts.value;
        return new ArraySerializerImpl(parse(item), key_extractor);
      }
      case "optional":
        return new OptionalSerializerImpl(parse(ts.value));
      case "primitive":
        return primitiveSerializer(ts.value) as InternalSerializer;
      case "record": {
        const recordId = ts.value;
        return recordBundles[recordId]!.serializer;
      }
    }
  }

  // Second loop: initialize each serializer.
  const initOps: Array<() => void> = [];
  for (const recordBundle of Object.values(recordBundles)) {
    const { definition, serializer } = recordBundle;
    const { defaultValue } = serializer;
    const { id, removed_numbers } = definition;
    const idParts = id.split(":");
    const module = idParts[0]!;
    const qualifiedName = idParts[1]!;
    const nameParts = qualifiedName.split(".");
    const name = nameParts[nameParts.length - 1]!;
    const parentId = module + ":" + nameParts.slice(0, -1).join(".");
    const parentType = recordBundles[parentId]?.serializer;
    const doc = definition.doc ?? "";
    switch (definition.kind) {
      case "struct": {
        const fields: StructFieldImpl[] = [];
        for (const f of definition.fields) {
          const fieldSerializer = parse(f.type!);
          fields.push(
            new StructFieldImpl(
              f.name,
              f.name,
              f.number,
              fieldSerializer,
              f.doc ?? "",
            ),
          );
          (defaultValue as AnyRecord)[f.name] = fieldSerializer.defaultValue;
        }
        const s = serializer as StructSerializerImpl<Json>;
        initOps.push(() =>
          s.init(name, module, parentType, doc, fields, removed_numbers ?? []),
        );
        break;
      }
      case "enum": {
        const s = serializer as EnumSerializerImpl<Json>;
        const variants = [UNKNOWN_VARIANT_DEFINITION]
          .concat(definition.variants)
          .map((f) =>
            f.type
              ? new EnumWrapperVariantImpl<Json>(
                  f.name,
                  f.number,
                  parse(f.type),
                  f.doc ?? "",
                  serializer.createFn,
                )
              : ({
                  name: f.name,
                  number: f.number,
                  constant: Object.freeze({ kind: f.name }),
                  doc: f.doc ?? "",
                } as EnumConstantVariant<Json>),
          );
        initOps.push(() =>
          s.init(
            name,
            module,
            parentType,
            doc,
            variants,
            removed_numbers ?? [],
          ),
        );
        break;
      }
    }
  }
  // We need to actually initialize the serializers *after* the default values
  // were constructed, because `init` calls `freezeDeeply` and this might result
  // in freezing the default of another serializer.
  initOps.forEach((op) => op());

  return parse(typeDefinition.type).typeDescriptor;
}

/**
 * Returns a `TypeDescriptor` from its JSON code representation as returned by
 * `asJsonCode()`.
 */
export function parseTypeDescriptorFromJsonCode(code: string): TypeDescriptor {
  return parseTypeDescriptorFromJson(JSON.parse(code));
}
