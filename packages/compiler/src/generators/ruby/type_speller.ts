import type {
  Module,
  RecordKey,
  RecordLocation,
  ResolvedType,
} from "skir-internal";
import { ClassName, getClassName } from "./class_speller.js";
import { RubyType } from "./ruby_type.js";

export type TypeFlavor =
  "initializer" | "frozen" | "maybe-mutable" | "mutable" | "kind";

export class TypeSpeller {
  constructor(
    readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    private readonly origin: Module,
    private readonly config: {
      modulePrefix?: string;
    },
  ) {}

  getRubyType(
    type: ResolvedType,
    flavor: "initializer" | "frozen" | "mutable" | "kind",
    allRecordsFrozen?: undefined,
  ): RubyType;

  getRubyType(
    type: ResolvedType,
    flavor: TypeFlavor,
    allRecordsFrozen: boolean | undefined,
  ): RubyType;

  getRubyType(
    type: ResolvedType,
    flavor: TypeFlavor,
    allRecordsFrozen: boolean | undefined,
  ): RubyType {
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
            return RubyType.of(className);
          } else if (flavor === "maybe-mutable" || flavor === "initializer") {
            return RubyType.of(
              allRecordsFrozen ? className : `${className}::OrMutable`,
            );
          } else if (flavor === "mutable") {
            return RubyType.of(`${className}::Mutable`);
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
          return RubyType.of(className);
        } else if (flavor === "kind") {
          return RubyType.of(`${className}::Kind`);
        } else {
          const _: never = flavor;
          throw TypeError();
        }
      }
      case "array": {
        const maybeMutableItemType = this.getRubyType(
          type.item,
          "maybe-mutable",
          allRecordsFrozen,
        );
        if (flavor === "initializer") {
          return RubyType.of(`T::Enumerable[${maybeMutableItemType}]`);
        }
        const frozenItemType = this.getRubyType(
          type.item,
          "frozen",
          allRecordsFrozen,
        );
        let frozenArrayType: RubyType;
        if (type.key) {
          const keyType = this.getRubyType(type.key.keyType, "kind");
          frozenArrayType = RubyType.of(
            `Skir::KeyedItems[${frozenItemType}, ${keyType}]`,
          );
        } else {
          frozenArrayType = RubyType.of(`T::Array[${frozenItemType}]`);
        }
        const mutableArrayType = RubyType.of(
          `T::Array[${maybeMutableItemType}]`,
        );
        if (flavor === "frozen") {
          return frozenArrayType;
        } else if (flavor === "maybe-mutable") {
          return RubyType.union([frozenArrayType, mutableArrayType]);
        } else if (flavor === "mutable") {
          return mutableArrayType;
        } else {
          const _: "kind" = flavor;
          throw TypeError();
        }
      }
      case "optional": {
        const otherType = this.getRubyType(
          type.other,
          flavor,
          allRecordsFrozen,
        );
        if (flavor === "mutable") {
          return otherType;
        }
        return RubyType.nilable(otherType);
      }
      case "primitive": {
        const { primitive } = type;
        switch (primitive) {
          case "bool":
            return RubyType.BOOL;
          case "int32":
          case "int64":
          case "hash64":
            return RubyType.INT;
          case "float32":
          case "float64":
            return flavor === "initializer" || flavor === "maybe-mutable"
              ? RubyType.NUMERIC
              : RubyType.FLOAT;
          case "timestamp":
            return RubyType.TIMESTAMP;
          case "string":
            return RubyType.STR;
          case "bytes":
            return RubyType.BYTES;
        }
      }
    }
  }

  getClassName(recordKey: RecordKey): ClassName {
    const record = this.recordMap.get(recordKey)!;
    return getClassName(record, this.origin, this.config);
  }
}
