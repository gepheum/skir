import type { RecordKey, RecordLocation, ResolvedType } from "skir-internal";
import { ClassName, Namer } from "./naming.js";

export type TypeFlavor =
  "initializer" | "frozen" | "maybe-mutable" | "mutable" | "kind";

/**
 * Transforms a type found in a `.skir` file into a Kotlin type.
 *
 * The flavors are:
 *   · initializer
 *       The value can be passed by parameter to the constructor of a frozen
 *       class.
 *   · frozen:
 *       The type is deeply immutable. All the fields of a frozen class are also
 *       frozen.
 *   · maybe-mutable:
 *       Type union of the frozen type and the mutable type. All the fields of a
 *       mutable class are maybe-mutable.
 *   · mutable:
 *       A mutable value. Not all types found in `.skir` files support this, e.g.
 *       strings and numbers are always immutable.
 */
export class TypeSpeller {
  constructor(
    readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    private readonly namer: Namer,
  ) {}

  getKotlinType(
    type: ResolvedType,
    flavor: "initializer" | "frozen" | "mutable",
    allRecordsFrozen?: undefined,
  ): string;

  getKotlinType(
    type: ResolvedType,
    flavor: TypeFlavor,
    // Only matters if mode is "maybe-mutable"
    allRecordsFrozen: boolean | undefined,
  ): string;

  getKotlinType(
    type: ResolvedType,
    flavor: TypeFlavor,
    // Only matters if mode is "maybe-mutable"
    allRecordsFrozen: boolean | undefined,
  ): string {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const record = recordLocation.record;
        const className = this.namer.getClassName(recordLocation).qualifiedName;
        if (record.recordType === "struct") {
          if (flavor === "frozen" || allRecordsFrozen) {
            return className;
          } else if (flavor === "maybe-mutable" || flavor === "initializer") {
            return allRecordsFrozen ? className : `${className}_OrMutable`;
          } else if (flavor === "mutable") {
            return `${className}.Mutable`;
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
          return className;
        } else if (flavor === "kind") {
          return `${className}.Kind`;
        } else {
          const _: never = flavor;
          throw TypeError();
        }
      }
      case "array": {
        if (flavor === "initializer") {
          const itemType = this.getKotlinType(
            type.item,
            "maybe-mutable",
            allRecordsFrozen,
          );
          return `kotlin.collections.Iterable<${itemType}>`;
        } else if (flavor === "frozen") {
          const itemType = this.getKotlinType(
            type.item,
            "frozen",
            allRecordsFrozen,
          );
          if (type.key) {
            const { keyType } = type.key;
            let kotlinKeyType = this.getKotlinType(keyType, "frozen");
            if (keyType.kind === "record") {
              kotlinKeyType += ".Kind";
            }
            return `build.skir.KeyedList<${itemType}, ${kotlinKeyType}>`;
          } else {
            return `kotlin.collections.List<${itemType}>`;
          }
        } else if (flavor === "maybe-mutable") {
          const itemType = this.getKotlinType(
            type.item,
            "maybe-mutable",
            allRecordsFrozen,
          );
          return `kotlin.collections.List<${itemType}>`;
        } else if (flavor === "mutable") {
          const itemType = this.getKotlinType(
            type.item,
            "maybe-mutable",
            allRecordsFrozen,
          );
          return `kotlin.collections.MutableList<${itemType}>`;
        } else {
          const _: "kind" = flavor;
          throw TypeError();
        }
      }
      case "optional": {
        const otherType = this.getKotlinType(
          type.other,
          flavor,
          allRecordsFrozen,
        );
        return `${otherType}?`;
      }
      case "primitive": {
        const { primitive } = type;
        switch (primitive) {
          case "bool":
            return "kotlin.Boolean";
          case "int32":
            return "kotlin.Int";
          case "int64":
            return "kotlin.Long";
          case "hash64":
            return "kotlin.ULong";
          case "float32":
            return "kotlin.Float";
          case "float64":
            return "kotlin.Double";
          case "timestamp":
            return "java.time.Instant";
          case "string":
            return "kotlin.String";
          case "bytes":
            return "okio.ByteString";
        }
      }
    }
  }

  getClassName(recordKey: RecordKey): ClassName {
    const record = this.recordMap.get(recordKey)!;
    return this.namer.getClassName(record);
  }

  getSerializerExpression(
    type: ResolvedType,
    registryModulePath: string | null,
  ): string {
    switch (type.kind) {
      case "primitive": {
        switch (type.primitive) {
          case "bool":
            return "build.skir.Serializers.bool";
          case "int32":
            return "build.skir.Serializers.int32";
          case "int64":
            return "build.skir.Serializers.int64";
          case "hash64":
            return "build.skir.Serializers.hash64";
          case "float32":
            return "build.skir.Serializers.float32";
          case "float64":
            return "build.skir.Serializers.float64";
          case "timestamp":
            return "build.skir.Serializers.timestamp";
          case "string":
            return "build.skir.Serializers.string";
          case "bytes":
            return "build.skir.Serializers.bytes";
        }
        const _: never = type.primitive;
        throw TypeError();
      }
      case "array": {
        if (type.key) {
          const keyChain = type.key.path.map((f) => f.name.text).join(".");
          const path = type.key.path
            .map((f) => this.namer.structFieldToKotlinName(f.name.text))
            .join(".");
          return (
            "build.skir.internal.keyedListSerializer(\n" +
            this.getSerializerExpression(type.item, registryModulePath) +
            `,\n"${keyChain}",\n{ it.${path} },\n)`
          );
        } else {
          return (
            "build.skir.Serializers.list(\n" +
            this.getSerializerExpression(type.item, registryModulePath) +
            ",\n)"
          );
        }
      }
      case "optional": {
        return (
          `build.skir.Serializers.optional(\n` +
          this.getSerializerExpression(type.other, registryModulePath) +
          `,\n)`
        );
      }
      case "record": {
        const record = this.recordMap.get(type.key)!;
        if (record.modulePath === registryModulePath) {
          return `_SerializerRegistry.${this.getRegistrySerializerName(record)}`;
        }
        return this.getClassName(type.key).qualifiedName + ".serializer";
      }
    }
  }

  getRegistrySerializerName(record: RecordLocation): string {
    return (
      this.namer
        .getClassName(record)
        .qualifiedName.split(".")
        .slice(-record.recordAncestors.length)
        .join("_") + "Serializer"
    );
  }
}
