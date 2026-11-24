import type { RecordKey, RecordLocation, ResolvedType } from "skir-internal";
import { ClassName, Namer } from "./naming.js";

export type TypeFlavor = "initializer" | "frozen" | "frozen-key";

/**
 * Transforms a type found in a `.skir` file into a Java type.
 */
export class TypeSpeller {
  constructor(
    readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    private readonly namer: Namer,
  ) {}

  getJavaType(
    type: ResolvedType,
    flavor: TypeFlavor,
    mustBeObject?: "must-be-object",
  ): string {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const record = recordLocation.record;
        const className = this.namer.getClassName(recordLocation).qualifiedName;
        if (record.recordType === "struct") {
          return className;
        }
        // An enum.
        const _: "enum" = record.recordType;
        if (flavor === "initializer" || flavor === "frozen") {
          return className;
        } else if (flavor === "frozen-key") {
          return `${className}.Kind`;
        } else {
          const _: never = flavor;
          throw TypeError();
        }
      }
      case "array": {
        const itemType = this.getJavaType(type.item, flavor, "must-be-object");
        if (flavor === "initializer") {
          return `java.lang.Iterable<? extends ${itemType}>`;
        } else if (flavor === "frozen" || flavor === "frozen-key") {
          if (type.key) {
            const { keyType } = type.key;
            const javaKeyType = this.getJavaType(
              keyType,
              "frozen-key",
              "must-be-object",
            );
            return `build.skir.KeyedList<${itemType}, ${javaKeyType}>`;
          } else {
            return `java.util.List<${itemType}>`;
          }
        } else {
          const _: "kind" = flavor;
          throw TypeError();
        }
      }
      case "optional": {
        const otherType = this.getJavaType(
          type.other,
          flavor,
          "must-be-object",
        );
        return `java.util.Optional<${otherType}>`;
      }
      case "primitive": {
        const { primitive } = type;
        if (mustBeObject) {
          switch (primitive) {
            case "bool":
              return "java.lang.Boolean";
            case "int32":
              return "java.lang.Integer";
            case "int64":
            case "hash64":
              return "java.lang.Long";
            case "float32":
              return "java.lang.Float";
            case "float64":
              return "java.lang.Double";
            case "timestamp":
              return "java.time.Instant";
            case "string":
              return "java.lang.String";
            case "bytes":
              return "okio.ByteString";
            default: {
              const _: never = primitive;
              throw TypeError();
            }
          }
        } else {
          switch (primitive) {
            case "bool":
              return "boolean";
            case "int32":
              return "int";
            case "int64":
            case "hash64":
              return "long";
            case "float32":
              return "float";
            case "float64":
              return "double";
            case "timestamp":
              return "java.time.Instant";
            case "string":
              return "java.lang.String";
            case "bytes":
              return "okio.ByteString";
            default: {
              const _: never = primitive;
              throw TypeError();
            }
          }
        }
      }
    }
  }

  getClassName(recordKey: RecordKey): ClassName {
    const record = this.recordMap.get(recordKey)!;
    return this.namer.getClassName(record);
  }

  getSerializerExpression(type: ResolvedType): string {
    switch (type.kind) {
      case "primitive": {
        switch (type.primitive) {
          case "bool":
            return "build.skir.Serializers.bool()";
          case "int32":
            return "build.skir.Serializers.int32()";
          case "int64":
            return "build.skir.Serializers.int64()";
          case "hash64":
            return "build.skir.Serializers.javaHash64()";
          case "float32":
            return "build.skir.Serializers.float32()";
          case "float64":
            return "build.skir.Serializers.float64()";
          case "timestamp":
            return "build.skir.Serializers.timestamp()";
          case "string":
            return "build.skir.Serializers.string()";
          case "bytes":
            return "build.skir.Serializers.bytes()";
        }
        const _: never = type.primitive;
        throw TypeError();
      }
      case "array": {
        if (type.key) {
          const keyChain = type.key.path.map((f) => f.name.text).join(".");
          const path = type.key.path
            .map((f) => this.namer.structFieldToJavaName(f.name.text) + "()")
            .join(".");
          return (
            "build.skir.internal.ListSerializerKt.keyedListSerializer(\n" +
            this.getSerializerExpression(type.item) +
            `,\n"${keyChain}",\n(it) -> it.${path}\n)`
          );
        } else {
          return (
            "build.skir.Serializers.list(\n" +
            this.getSerializerExpression(type.item) +
            "\n)"
          );
        }
      }
      case "optional": {
        return (
          `build.skir.Serializers.javaOptional(\n` +
          this.getSerializerExpression(type.other) +
          `\n)`
        );
      }
      case "record": {
        return this.getClassName(type.key).qualifiedName + ".SERIALIZER";
      }
    }
  }
}
