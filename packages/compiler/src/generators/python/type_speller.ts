import type {
  Module,
  RecordKey,
  RecordLocation,
  ResolvedType,
} from "skir-internal";
import { ClassName, getClassName } from "./class_speller.js";
import { PyType } from "./py_type.js";

export type TypeFlavor =
  "initializer" | "frozen" | "maybe-mutable" | "mutable" | "kind";

/**
 * Transforms a type found in a '.skir' file into a Python type.
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
    private readonly config: {
      packagePrefix?: string;
    },
  ) {}

  getPyType(
    type: ResolvedType,
    flavor: "initializer" | "frozen" | "mutable" | "kind",
    allRecordsFrozen?: undefined,
  ): PyType;

  getPyType(
    type: ResolvedType,
    flavor: TypeFlavor,
    // Only matters if mode is "maybe-mutable"
    allRecordsFrozen: boolean | undefined,
  ): PyType;

  getPyType(
    type: ResolvedType,
    flavor: TypeFlavor,
    // Only matters if mode is "maybe-mutable"
    allRecordsFrozen: boolean | undefined,
  ): PyType {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const record = recordLocation.record;
        const className = getClassName(
          recordLocation,
          this.origin,
          this.config,
        ).qualifiedName;
        if (record.recordType === "struct") {
          if (flavor === "frozen" || allRecordsFrozen) {
            return PyType.quote(className);
          } else if (flavor === "maybe-mutable" || flavor === "initializer") {
            return PyType.quote(
              allRecordsFrozen ? className : `${className}.OrMutable`,
            );
          } else if (flavor === "mutable") {
            return PyType.quote(`${className}.Mutable`);
          } else {
            const _: "kind" = flavor;
            throw TypeError();
          }
        }
        // An enum.
        const _: "enum" = record.recordType;
        if (
          flavor === "initializer" ||
          flavor === "frozen" ||
          flavor === "maybe-mutable" ||
          flavor === "mutable"
        ) {
          return PyType.quote(className);
        } else if (flavor === "kind") {
          return PyType.quote(`${className}.Kind`);
        } else {
          const _: never = flavor;
          throw TypeError();
        }
      }
      case "array": {
        const maybeMutableItemType = this.getPyType(
          type.item,
          "maybe-mutable",
          allRecordsFrozen,
        );
        if (flavor === "initializer") {
          return PyType.of(`collections.abc.Iterable[${maybeMutableItemType}]`);
        }
        const frozenItemType = this.getPyType(
          type.item,
          "frozen",
          allRecordsFrozen,
        );
        let tupleType: PyType;
        if (type.key) {
          const keyType = this.getPyType(type.key.keyType, "kind");
          tupleType = PyType.of(
            `skir.KeyedItems[${frozenItemType}, ${keyType}]`,
          );
        } else {
          tupleType = PyType.of(`tuple[${frozenItemType}, ...]`);
        }
        const listType = PyType.of(`list[${maybeMutableItemType}]`);
        if (flavor === "frozen") {
          return tupleType;
        } else if (flavor === "maybe-mutable") {
          return PyType.union([tupleType, listType]);
        } else if (flavor === "mutable") {
          return listType;
        } else {
          const _: "kind" = flavor;
          throw TypeError();
        }
      }
      case "optional": {
        const otherType = this.getPyType(type.other, flavor, allRecordsFrozen);
        if (flavor === "mutable") {
          // The generated mutableX() methods cannot return null.
          return otherType;
        }
        return PyType.union([otherType, PyType.NONE]);
      }
      case "primitive": {
        const { primitive } = type;
        switch (primitive) {
          case "bool":
            return PyType.BOOL;
          case "int32":
          case "int64":
          case "hash64":
            return PyType.INT;
          case "float32":
          case "float64":
            return PyType.FLOAT;
          case "timestamp":
            return PyType.TIMESTAMP;
          case "string":
            return PyType.STR;
          case "bytes":
            return PyType.BYTES;
        }
      }
    }
  }

  getClassName(recordKey: RecordKey): ClassName {
    const record = this.recordMap.get(recordKey)!;
    return getClassName(record, this.origin, this.config);
  }
}
