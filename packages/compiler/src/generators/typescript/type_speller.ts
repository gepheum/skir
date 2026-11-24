import type {
  Module,
  RecordKey,
  RecordLocation,
  ResolvedType,
} from "skir-internal";
import { ClassName, getClassName } from "./class_speller.js";
import { TsType } from "./ts_type.js";

export type TypeFlavor = "initializer" | "frozen" | "maybe-mutable" | "mutable";

/**
 * Transforms a type found in a '.skir' file into a TypeScript type.
 *
 * The flavors are:
 *   · initializer
 *       The value can be passed by parameter to the `create` method of a frozen
 *       class or the constructor of a mutable class.
 *   · frozen:
 *       The type is deeply immutable. All the fields of a frozen class are also
 *       frozen.
 *   · maybe-mutable:
 *       Type union of the frozen type and the mutable type. All the fields of a
 *       mutable class are maybe-mutable.
 *   · mutable:
 *       A mutable value. Not all types found in '.skir' files support this, e.g.
 *       strings and numbers are always immutable.
 */
export class TypeSpeller {
  constructor(
    readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    private readonly origin: Module,
  ) {}

  getTsType(
    type: ResolvedType,
    flavor: "initializer" | "frozen" | "mutable",
    allRecordsFrozen?: undefined,
  ): TsType;

  getTsType(
    type: ResolvedType,
    flavor: TypeFlavor,
    // Only matters if mode is "maybe-mutable"
    allRecordsFrozen: boolean | undefined,
  ): TsType;

  getTsType(
    type: ResolvedType,
    flavor: TypeFlavor,
    // Only matters if mode is "maybe-mutable"
    allRecordsFrozen: boolean | undefined,
  ): TsType {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const record = recordLocation.record;
        const classRef = getClassName(recordLocation, this.origin).type;
        if (record.recordType === "struct") {
          if (flavor === "initializer") {
            return TsType.simple(`${classRef}.Initializer<_Wholeness>`);
          } else if (flavor === "frozen" || allRecordsFrozen) {
            return TsType.simple(classRef);
          } else if (flavor === "maybe-mutable") {
            return allRecordsFrozen
              ? TsType.simple(classRef)
              : TsType.simple(`${classRef}.OrMutable`);
          } else if (flavor === "mutable") {
            return TsType.simple(`${classRef}.Mutable`);
          } else {
            const _: never = flavor;
            throw TypeError();
          }
        }
        // An enum.
        if (flavor === "initializer") {
          return TsType.simple(`${classRef}.Initializer<_Wholeness>`);
        } else if (flavor === "frozen" || flavor === "maybe-mutable") {
          return TsType.simple(classRef);
        } else if (flavor === "mutable") {
          // Enum types are immutable.
          return TsType.NEVER;
        } else {
          const _: never = flavor;
          throw TypeError();
        }
      }
      case "array": {
        if (
          flavor === "frozen" ||
          flavor === "initializer" ||
          flavor === "maybe-mutable"
        ) {
          const itemType = this.getTsType(type.item, flavor, allRecordsFrozen);
          return TsType.generic("ReadonlyArray", itemType);
        } else if (flavor === "mutable") {
          const itemType = this.getTsType(
            type.item,
            "maybe-mutable",
            allRecordsFrozen,
          );
          return TsType.generic("Array", itemType);
        } else {
          const _: never = flavor;
          throw TypeError();
        }
      }
      case "optional": {
        const valueType = this.getTsType(type.other, flavor, allRecordsFrozen);
        return TsType.union([valueType, TsType.NULL]);
      }
      case "primitive": {
        if (flavor === "mutable") {
          // Don't add a mutableX getter to the Mutable class if x is immutable.
          // All primitive types are immutable.
          return TsType.NEVER;
        }
        const { primitive } = type;
        switch (primitive) {
          case "bool":
            return TsType.BOOLEAN;
          case "int32":
          case "float32":
          case "float64":
            return TsType.NUMBER;
          case "int64":
          case "hash64":
            return TsType.BIGINT;
          case "timestamp":
            return TsType.TIMESTAMP;
          case "string":
            return TsType.STRING;
          case "bytes":
            return TsType.BYTE_STRING;
        }
      }
    }
  }

  getClassName(recordKey: RecordKey): ClassName {
    const record = this.recordMap.get(recordKey)!;
    return getClassName(record, this.origin);
  }
}

export const TYPE_FLAVORS: ReadonlySet<TypeFlavor> = new Set([
  "initializer",
  "frozen",
  "maybe-mutable",
  "mutable",
]);
