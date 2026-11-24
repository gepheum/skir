import type { ByteString } from "../byte-string.js";
import type { InternalSerializer, Json } from "../serializers/base.js";
import type { AnyRecord } from "../serializers/records.js";
import type { StructDescriptor } from "../serializers/type-descriptor.js";

interface FrozenArrayInfo {
  keyFnToIndexing?: Map<unknown, Map<unknown, unknown>>;
}

export const frozenArrayRegistry = new WeakMap<
  ReadonlyArray<unknown>,
  FrozenArrayInfo
>();

export function freezeArray<T>(array: readonly T[]): readonly T[] {
  if (!frozenArrayRegistry.has(array)) {
    frozenArrayRegistry.set(Object.freeze(array), {});
  }
  return array;
}

export const _EMPTY_ARRAY = freezeArray([]);

export function _toFrozenArray<T, Initializer>(
  initializers: readonly Initializer[],
  itemToFrozenFn?: (item: Initializer) => T,
): readonly T[] {
  if (!initializers.length) {
    return _EMPTY_ARRAY;
  }
  if (frozenArrayRegistry.has(initializers)) {
    // No need to make a copy: the given array is already deeply-frozen.
    return initializers as unknown as readonly T[];
  }
  const ret = Object.freeze(
    itemToFrozenFn
      ? initializers.map(itemToFrozenFn)
      : (initializers.slice() as unknown as readonly T[]),
  );
  frozenArrayRegistry.set(ret, {});
  return ret;
}

export class UnrecognizedEnum {
  constructor(
    readonly token: symbol,
    readonly json?: Json,
    readonly bytes?: ByteString,
  ) {
    Object.freeze(this);
  }
}

export declare const _INITIALIZER: unique symbol;

export const PRIVATE_KEY: unique symbol = Symbol();

function forPrivateUseError(t: unknown): Error {
  const clazz = Object.getPrototypeOf(t).constructor as AnyRecord;
  const { qualifiedName } = clazz.serializer as StructDescriptor;
  return Error(
    [
      "Do not call the constructor directly; ",
      `instead, call ${qualifiedName}.create(...)`,
    ].join(""),
  );
}

export abstract class _FrozenBase {
  protected constructor(privateKey: symbol) {
    if (privateKey !== PRIVATE_KEY) {
      throw forPrivateUseError(this);
    }
  }

  toMutable(): unknown {
    return new (Object.getPrototypeOf(this).constructor.Mutable)(this);
  }

  toFrozen(): this {
    return this;
  }

  toString(): string {
    return toStringImpl(this);
  }

  declare [_INITIALIZER]: unknown;
}

export abstract class _EnumBase {
  protected constructor(
    privateKey: symbol,
    kind: string,
    value: unknown,
    unrecognized?: UnrecognizedEnum,
  ) {
    if (privateKey !== PRIVATE_KEY) {
      throw forPrivateUseError(this);
    }
    (this as AnyRecord).kind = kind;
    (this as AnyRecord).value = value;
    if (unrecognized) {
      if (!(unrecognized instanceof UnrecognizedEnum)) {
        throw new TypeError();
      }
      (this as AnyRecord)["^"] = unrecognized;
    }
    Object.freeze(this);
  }

  declare readonly union: {
    kind: unknown;
    value: unknown;
  };

  toString(): string {
    return toStringImpl(this);
  }
}

// The TypeScript compiler complains if we define the property within the class.
Object.defineProperty(_EnumBase.prototype, "union", {
  get: function () {
    return this;
  },
});

function toStringImpl<T>(value: T): string {
  const serializer = Object.getPrototypeOf(value).constructor
    .serializer as InternalSerializer<T>;
  return serializer.toJsonCode(value, "readable");
}
