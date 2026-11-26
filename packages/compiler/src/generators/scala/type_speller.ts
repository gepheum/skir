import type { RecordKey, RecordLocation, ResolvedType } from "skir-internal";
import { ClassName, Namer } from "./naming.js";

export type TypeFlavor =
  "initializer" | "frozen" | "boxed" | "maybe-mutable" | "mutable" | "kind";

/**
 * Transforms a type found in a `.skir` file into a Scala type.
 *
 * The flavors are:
 *   · initializer:
 *       The value can be passed by parameter to the constructor / apply / copy
 *       method of a frozen class.
 *   · frozen:
 *       The type is deeply immutable. All the fields of a frozen class are also
 *       frozen.
 *   · boxed:
 *       Like `frozen`, except primitive types use their `java.lang.*` boxed
 *       counterparts for Java generic interop (`java.util.List`, `java.util.Optional`,
 *       `build.skir.Serializer`, `build.skir.KeyedList`).
 *   · maybe-mutable:
 *       Supertype of the frozen type and the mutable type. All the fields of a
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

  needsConversionToFrozen(
    type: ResolvedType,
    allRecordsFrozen?: boolean,
  ): boolean {
    switch (type.kind) {
      case "primitive":
        return false;
      case "record":
        return !allRecordsFrozen && type.recordType === "struct";
      case "optional":
        return this.needsConversionToFrozen(type.other, allRecordsFrozen);
      case "array":
        return true;
    }
  }

  getScalaType(
    type: ResolvedType,
    flavor: "initializer" | "frozen" | "boxed" | "mutable",
    allRecordsFrozen?: undefined,
    inGeneric?: boolean,
  ): string;

  getScalaType(
    type: ResolvedType,
    flavor: TypeFlavor,
    // Only matters if flavor is "maybe-mutable"
    allRecordsFrozen: boolean | undefined,
    inGeneric?: boolean,
  ): string;

  getScalaType(
    type: ResolvedType,
    flavor: TypeFlavor,
    // Only matters if flavor is "maybe-mutable"
    allRecordsFrozen: boolean | undefined,
    inGeneric = false,
  ): string {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const record = recordLocation.record;
        const className = this.namer.getClassName(recordLocation).qualifiedName;
        if (record.recordType === "struct") {
          if (flavor === "frozen" || flavor === "boxed" || allRecordsFrozen) {
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
          flavor === "boxed" ||
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
          const itemType = this.getScalaType(
            type.item,
            "initializer",
            allRecordsFrozen,
            true,
          );
          return `_root_.java.lang.Iterable[? <: ${itemType}]`;
        } else if (
          flavor === "frozen" ||
          flavor === "boxed" ||
          (flavor === "maybe-mutable" && allRecordsFrozen)
        ) {
          const itemType = this.getScalaType(
            type.item,
            "boxed",
            allRecordsFrozen,
            true,
          );
          if (type.key) {
            const { keyType } = type.key;
            let scalaKeyType = this.getScalaType(
              keyType,
              "boxed",
              undefined,
              true,
            );
            if (keyType.kind === "record") {
              scalaKeyType += ".Kind";
            }
            return `_root_.build.skir.KeyedList[${itemType}, ${scalaKeyType}]`;
          } else {
            return `_root_.java.util.List[${itemType}]`;
          }
        } else if (flavor === "maybe-mutable") {
          if (!this.needsConversionToFrozen(type.item, allRecordsFrozen)) {
            const itemType = this.getScalaType(
              type.item,
              "boxed",
              allRecordsFrozen,
              true,
            );
            return `_root_.java.util.List[${itemType}]`;
          }
          const itemType = this.getScalaType(
            type.item,
            "maybe-mutable",
            allRecordsFrozen,
            true,
          );
          return `_root_.java.util.List[? <: ${itemType}]`;
        } else if (flavor === "mutable") {
          const itemType = this.getScalaType(
            type.item,
            "maybe-mutable",
            allRecordsFrozen,
            true,
          );
          return `_root_.build.skir.internal.MutableList[${itemType}]`;
        } else {
          const _: "kind" = flavor;
          throw TypeError();
        }
      }
      case "optional": {
        if (
          flavor === "frozen" ||
          flavor === "boxed" ||
          (flavor === "maybe-mutable" && allRecordsFrozen) ||
          !this.needsConversionToFrozen(type.other, allRecordsFrozen)
        ) {
          const otherType = this.getScalaType(
            type.other,
            "boxed",
            allRecordsFrozen,
            true,
          );
          return `_root_.java.util.Optional[${otherType}]`;
        } else {
          const innerFlavor =
            flavor === "initializer" ? "initializer" : "maybe-mutable";
          const otherType = this.getScalaType(
            type.other,
            innerFlavor,
            allRecordsFrozen,
            true,
          );
          return `_root_.java.util.Optional[? <: ${otherType}]`;
        }
      }
      case "primitive": {
        const { primitive } = type;
        const useBoxed = flavor === "boxed" || inGeneric;
        switch (primitive) {
          case "bool":
            return useBoxed
              ? "_root_.java.lang.Boolean"
              : "_root_.scala.Boolean";
          case "int32":
            return useBoxed ? "_root_.java.lang.Integer" : "_root_.scala.Int";
          case "int64":
          case "hash64":
            return useBoxed ? "_root_.java.lang.Long" : "_root_.scala.Long";
          case "float32":
            return useBoxed ? "_root_.java.lang.Float" : "_root_.scala.Float";
          case "float64":
            return useBoxed ? "_root_.java.lang.Double" : "_root_.scala.Double";
          case "timestamp":
            return "_root_.java.time.Instant";
          case "string":
            return "_root_.java.lang.String";
          case "bytes":
            return "_root_.okio.ByteString";
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
            return "_root_.build.skir.Serializers.bool()";
          case "int32":
            return "_root_.build.skir.Serializers.int32()";
          case "int64":
            return "_root_.build.skir.Serializers.int64()";
          case "hash64":
            return "_root_.build.skir.Serializers.javaHash64()";
          case "float32":
            return "_root_.build.skir.Serializers.float32()";
          case "float64":
            return "_root_.build.skir.Serializers.float64()";
          case "timestamp":
            return "_root_.build.skir.Serializers.timestamp()";
          case "string":
            return "_root_.build.skir.Serializers.string()";
          case "bytes":
            return "_root_.build.skir.Serializers.bytes()";
        }
        const _: never = type.primitive;
        throw TypeError();
      }
      case "array": {
        if (type.key) {
          const keyChain = type.key.path.map((f) => f.name.text).join(".");
          const path = type.key.path
            .map((f) => this.namer.structFieldToScalaName(f.name.text))
            .join(".");
          const itemBoxedType = this.getScalaType(type.item, "boxed");
          const { keyType } = type.key;
          let keyBoxedType = this.getScalaType(keyType, "boxed");
          if (keyType.kind === "record") {
            keyBoxedType += ".Kind";
          }
          return (
            `_root_.build.skir.internal.ListSerializerKt.keyedListSerializer[${itemBoxedType}, ${keyBoxedType}](\n` +
            this.getSerializerExpression(type.item, registryModulePath) +
            `,\n"${keyChain}",\n(_it: ${itemBoxedType}) => (_it.${path} : ${keyBoxedType}),\n)`
          );
        } else {
          return (
            "_root_.build.skir.Serializers.list(\n" +
            this.getSerializerExpression(type.item, registryModulePath) +
            ",\n)"
          );
        }
      }
      case "optional": {
        return (
          `_root_.build.skir.Serializers.javaOptional(\n` +
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
