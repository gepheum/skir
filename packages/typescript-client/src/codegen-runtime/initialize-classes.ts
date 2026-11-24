import type {
  Freezable,
  InternalSerializer,
  Serializer,
} from "../serializers/base.js";
import {
  arraySerializer,
  optionalSerializer,
} from "../serializers/collections.js";
import { primitiveSerializer } from "../serializers/primitives.js";
import type { AnyRecord } from "../serializers/records.js";
import {
  EnumSerializerImpl,
  EnumWrapperVariantImpl,
  StructFieldImpl,
  StructSerializerImpl,
} from "../serializers/records.js";
import type {
  EnumDescriptor,
  PrimitiveTypes,
  StructDescriptor,
} from "../serializers/type-descriptor.js";
import { frozenArrayRegistry, PRIVATE_KEY, UnrecognizedEnum } from "./base.js";

interface StructSpec {
  kind: "struct";
  ctor: { new (privateKey: symbol): unknown };
  initFn: (target: unknown, initializer: unknown) => void;
  name: string;
  parentCtor?: { new (): unknown };
  doc?: string;
  fields: readonly StructFieldSpec[];
  removedNumbers?: readonly number[];
}

interface StructFieldSpec {
  name: string;
  property: string;
  number: number;
  type: TypeSpec;
  doc?: string;
  mutableGetter?: string;
  indexable?: IndexableSpec;
}

interface IndexableSpec {
  searchMethod: string;
  keyFn: (v: unknown) => unknown;
  keyToHashable?: (v: unknown) => unknown;
}

interface EnumSpec<Enum = unknown> {
  kind: "enum";
  ctor: {
    new (
      privateKey: symbol,
      kind: string,
      value?: unknown,
      unrecognized?: UnrecognizedEnum,
    ): Enum;
  };
  createValueFn?: (initializer: unknown) => unknown;
  name: string;
  parentCtor?: { new (): unknown };
  doc?: string;
  variants: EnumVariantSpec[];
  removedNumbers?: readonly number[];
}

interface EnumVariantSpec {
  name: string;
  number: number;
  type?: TypeSpec;
  doc?: string;
}

type TypeSpec =
  | {
      kind: "optional";
      other: TypeSpec;
    }
  | {
      kind: "array";
      item: TypeSpec;
      keyChain?: string;
    }
  | {
      kind: "record";
      ctor: { new (): unknown };
    }
  | {
      kind: "primitive";
      primitive: keyof PrimitiveTypes;
    };

// The UNKNOWN variant is common to all enums.
const UNKNOWN_VARIANT_SPEC: EnumVariantSpec = {
  name: "UNKNOWN",
  number: 0,
};

export function _initModuleClasses(
  modulePath: string,
  records: ReadonlyArray<StructSpec | EnumSpec>,
): void {
  const privateKey = PRIVATE_KEY;

  // First loop: add a serializer property to every record class.
  for (const record of records) {
    const clazz = record.ctor as unknown as AnyRecord;
    switch (record.kind) {
      case "struct": {
        const { ctor, initFn } = record;
        // Create the DEFAULT value. It will be initialized in a second loop.
        // To see why we can't initialize it in the first loop, consider this
        // example:
        //   struct Foo { bar: Bar; }
        //   struct Bar { foo: Foo; }
        // The default value for Foo must contain a reference to the default
        // value for Bar, and the default value for Bar also needs to contain
        // a reference to the default value for Foo.
        clazz.DEFAULT = new ctor(privateKey);
        // Expose the mutable class as a static property of the frozen class.
        const mutableCtor = makeMutableClassForRecord(record, clazz.DEFAULT);
        clazz.Mutable = mutableCtor;
        // Define the 'create' static factory function.
        const createFn = (initializer: unknown): unknown => {
          if (initializer instanceof ctor) {
            return initializer;
          }
          const ret = new ctor(privateKey);
          initFn(ret, initializer);
          if ((initializer as AnyRecord)["^"]) {
            (ret as AnyRecord)["^"] = (initializer as AnyRecord)["^"];
          }
          return Object.freeze(ret);
        };
        clazz.create = createFn;
        // Create the serializer. It will be initialized in a second loop.
        clazz.serializer = new StructSerializerImpl(
          clazz.DEFAULT,
          createFn as (initializer: AnyRecord) => unknown,
          () => new mutableCtor() as Freezable<unknown>,
        );
        break;
      }
      case "enum": {
        // Create the constants.
        // Prepend the UNKNOWN variant to the array of variants specified from the
        // generated code.
        record.variants = [UNKNOWN_VARIANT_SPEC].concat(record.variants);
        for (const variant of record.variants) {
          if (variant.type) {
            continue;
          }
          const property = variant.name;
          clazz[property] = new record.ctor(PRIVATE_KEY, variant.name);
        }
        // Define the 'create' static factory function.
        const createFn = makeCreateEnumFunction(record);
        clazz.create = createFn;
        // Create the serializer. It will be initialized in a second loop.
        clazz.serializer = new EnumSerializerImpl(createFn);
        break;
      }
    }
    // If the record is nested, expose the record class as a static property of
    // the parent class.
    if (record.parentCtor) {
      (record.parentCtor as unknown as AnyRecord)[record.name] = record.ctor;
    }
  }

  // Second loop: initialize the serializer of every record, initialize the
  // default value of every struct, and freeze every class so new properties
  // can't be added to it.
  for (const record of records) {
    const clazz = record.ctor as unknown as AnyRecord;
    const parentTypeDescriptor = (record.parentCtor as unknown as AnyRecord)
      ?.serializer as StructDescriptor | EnumDescriptor | undefined;
    switch (record.kind) {
      case "struct": {
        // Initializer serializer.
        const fields = record.fields.map(
          (f) =>
            new StructFieldImpl(
              f.name,
              f.property,
              f.number,
              getSerializerForType(f.type) as InternalSerializer,
              f.doc ?? "",
            ),
        );
        const serializer = clazz.serializer as StructSerializerImpl;
        serializer.init(
          record.name,
          modulePath,
          parentTypeDescriptor,
          record.doc ?? "",
          fields,
          record.removedNumbers ?? [],
        );
        // Initialize DEFAULT.
        const { DEFAULT } = clazz;
        record.initFn(DEFAULT as AnyRecord, {});
        Object.freeze(DEFAULT);
        // Define the mutable getters in the Mutable class.
        const mutableCtor = clazz.Mutable as new (i: unknown) => unknown;
        for (const field of record.fields) {
          if (field.mutableGetter) {
            Object.defineProperty(mutableCtor.prototype, field.mutableGetter, {
              get: makeMutableGetterFn(field),
            });
          }
        }
        // Define the search methods in the frozen class.
        for (const field of record.fields) {
          if (field.indexable) {
            record.ctor.prototype[field.indexable.searchMethod] =
              makeSearchMethod(field);
          }
        }
        // Freeze the frozen class and the mutable class.
        Object.freeze(record.ctor);
        Object.freeze(record.ctor.prototype);
        Object.freeze(clazz.Mutable);
        Object.freeze((clazz.Mutable as AnyRecord).prototype);
        break;
      }
      case "enum": {
        const serializer = clazz.serializer as EnumSerializerImpl;
        const variants = record.variants.map((f) =>
          f.type
            ? new EnumWrapperVariantImpl(
                f.name,
                f.number,
                getSerializerForType(f.type) as InternalSerializer,
                f.doc ?? "",
                serializer.createFn,
              )
            : {
                name: f.name,
                number: f.number,
                constant: clazz[f.name],
                doc: f.doc ?? "",
              },
        );
        serializer.init(
          record.name,
          modulePath,
          parentTypeDescriptor,
          record.doc ?? "",
          variants,
          record.removedNumbers ?? [],
        );
        // Freeze the enum class.
        Object.freeze(record.ctor);
        Object.freeze(record.ctor.prototype);
        break;
      }
    }
  }
}

function makeCreateEnumFunction(
  enumSpec: EnumSpec,
): (initializer: unknown) => unknown {
  const { ctor, createValueFn } = enumSpec;
  const createValue = createValueFn || ((): undefined => undefined);
  const privateKey = PRIVATE_KEY;
  return (initializer: unknown) => {
    if (initializer instanceof ctor) {
      return initializer;
    }
    if (typeof initializer === "string") {
      const maybeResult = (ctor as unknown as AnyRecord)[initializer];
      if (maybeResult instanceof ctor) {
        return maybeResult;
      }
      throw new Error(`Constant not found: ${initializer}`);
    }
    if (initializer instanceof UnrecognizedEnum) {
      return new ctor(privateKey, "UNKNOWN", undefined, initializer);
    }
    const kind = (initializer as { kind: string }).kind;
    if (kind === undefined) {
      throw new Error("Missing entry: kind");
    }
    const unrecognized = (initializer as AnyRecord)["^"] as
      UnrecognizedEnum | undefined;
    const value = createValue(initializer);
    if (value === undefined) {
      const maybeConstant = (ctor as unknown as AnyRecord)[kind];
      if (!(maybeConstant instanceof ctor)) {
        throw new Error(`Wrapper variant not found: ${kind}`);
      }
      return unrecognized
        ? new ctor(privateKey, kind, undefined, unrecognized)
        : maybeConstant;
    }
    return new ctor(privateKey, kind, value, unrecognized);
  };
}

function makeMutableClassForRecord(
  structSpec: StructSpec,
  defaultFrozen: unknown,
): new (initializer?: unknown) => unknown {
  const { ctor: frozenCtor, initFn } = structSpec;
  const frozenClass = frozenCtor as unknown as AnyRecord;
  class Mutable {
    constructor(initializer: unknown = defaultFrozen) {
      initFn(this, initializer);
      if ((initializer as AnyRecord)["^"]) {
        (this as AnyRecord)["^"] = (initializer as AnyRecord)["^"];
      }
      Object.seal(this);
    }

    toFrozen(): unknown {
      return (frozenClass.create as (i: unknown) => unknown)(this);
    }

    toString(): string {
      const serializer = frozenClass.serializer as Serializer<unknown>;
      return serializer.toJsonCode(this, "readable");
    }
  }
  return Mutable;
}

function getSerializerForType(type: TypeSpec): Serializer<unknown> {
  switch (type.kind) {
    case "array":
      return arraySerializer(getSerializerForType(type.item), type.keyChain);
    case "optional":
      return optionalSerializer(getSerializerForType(type.other));
    case "primitive":
      return primitiveSerializer(type.primitive);
    case "record":
      return (type.ctor as unknown as AnyRecord)
        .serializer as Serializer<unknown>;
  }
}

// The `mutableArray()` getter of the Mutable class returns `this.array` if and
// only if `mutableArray()` was never called before or if `this.array` is the
// last value returned by `mutableArray()`.
// Otherwise, it makes a mutable copy of `this.array`, assigns it to
// `this.array` and returns it.
const arraysReturnedByMutableGetters = new WeakMap<
  ReadonlyArray<unknown>,
  unknown
>();

function makeMutableGetterFn(field: StructFieldSpec): () => unknown {
  const { property, type } = field;
  switch (type.kind) {
    case "array": {
      class Class {
        static ret(): unknown {
          const value = this[property] as readonly unknown[];
          if (arraysReturnedByMutableGetters.get(value) === this) {
            return value;
          }
          const copy = [...value];
          arraysReturnedByMutableGetters.set(copy, this);
          return (this[property] = copy);
        }

        static [_: string]: unknown;
      }
      return Class.ret;
    }
    case "record": {
      const mutableCtor = (type.ctor as unknown as AnyRecord).Mutable as new (
        i: unknown,
      ) => unknown;
      class Class {
        static ret(): unknown {
          const value = this[property];
          if (value instanceof mutableCtor) {
            return value;
          }
          return (this[property] = new mutableCtor(value));
        }

        static [_: string]: unknown;
      }
      return Class.ret;
    }
    default: {
      throw new Error();
    }
  }
}

function makeSearchMethod(field: StructFieldSpec): (key: unknown) => unknown {
  const { property } = field;
  const indexable = field.indexable!;
  const { keyFn } = indexable;
  const keyToHashable = indexable.keyToHashable ?? ((e: unknown): unknown => e);
  class Class {
    ret(key: unknown): unknown {
      const array = this[property] as ReadonlyArray<unknown>;
      const frozenArrayInfo = frozenArrayRegistry.get(array)!;
      let { keyFnToIndexing } = frozenArrayInfo;
      if (!keyFnToIndexing) {
        frozenArrayInfo.keyFnToIndexing = keyFnToIndexing = //
          new Map<unknown, Map<unknown, unknown>>();
      }
      let hashableToValue = keyFnToIndexing.get(keyFn);
      if (!hashableToValue) {
        // The array has not been indexed yet. Index it.
        hashableToValue = new Map<unknown, unknown>();
        for (const v of array) {
          const hashable = keyToHashable(keyFn(v));
          hashableToValue.set(hashable, v);
        }
        keyFnToIndexing.set(keyFn, hashableToValue);
      }
      return hashableToValue.get(keyToHashable(key));
    }

    [_: string]: unknown;
  }
  return Class.prototype.ret;
}
