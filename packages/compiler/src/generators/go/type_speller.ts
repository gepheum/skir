import type { RecordKey, RecordLocation, ResolvedType } from "skir-internal";
import { getClassName, modulePathToAlias } from "./naming.js";

/**
 * Transforms a type found in a `.skir` file into a Go type.
 */
export class TypeSpeller {
  constructor(
    readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    readonly modulePath: string,
  ) {}

  getGoType(type: ResolvedType): string {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const className = getClassName(recordLocation);
        if (recordLocation.modulePath === this.modulePath) {
          return className;
        } else {
          const packageAlias = modulePathToAlias(recordLocation.modulePath);
          return `${packageAlias}.${className}`;
        }
      }
      case "array": {
        const itemType = this.getGoType(type.item);
        return `skir_client.Array[${itemType}]`;
      }
      case "optional": {
        const otherType = this.getGoType(type.other);
        return `skir_client.Optional[${otherType}]`;
      }
      case "primitive": {
        const { primitive } = type;
        switch (primitive) {
          case "bool":
          case "int32":
          case "int64":
          case "float32":
          case "float64":
          case "string":
            return primitive;
          case "hash64":
            return "uint64";
          case "timestamp":
            return "time.Time";
          case "bytes":
            return "skir_client.Bytes";
        }
      }
    }
  }

  getClassName(recordKey: RecordKey): string {
    const record = this.recordMap.get(recordKey)!;
    return getClassName(record);
  }

  getSerializerExpression(type: ResolvedType): string {
    switch (type.kind) {
      case "primitive": {
        switch (type.primitive) {
          case "bool":
            return "skir_client.BoolSerializer()";
          case "int32":
            return "skir_client.Int32Serializer()";
          case "int64":
            return "skir_client.Int64Serializer()";
          case "hash64":
            return "skir_client.Hash64Serializer()";
          case "float32":
            return "skir_client.Float32Serializer()";
          case "float64":
            return "skir_client.Float64Serializer()";
          case "timestamp":
            return "skir_client.TimestampSerializer()";
          case "string":
            return "skir_client.StringSerializer()";
          case "bytes":
            return "skir_client.BytesSerializer()";
        }
        const _: never = type.primitive;
        throw TypeError();
      }
      case "array": {
        if (type.key) {
          const keyExtractor = type.key.path
            .map((part) => part.name.text)
            .join(".");
          return (
            "skir_client.Internal__ArraySerializer(\n" +
            this.getSerializerExpression(type.item) +
            ",\n" +
            JSON.stringify(keyExtractor) +
            ",\n)"
          );
        } else {
          return (
            "skir_client.ArraySerializer(\n" +
            this.getSerializerExpression(type.item) +
            ",\n)"
          );
        }
      }
      case "optional": {
        return (
          "skir_client.OptionalSerializer(\n" +
          this.getSerializerExpression(type.other) +
          ",\n)"
        );
      }
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const className = getClassName(recordLocation);
        if (recordLocation.modulePath === this.modulePath) {
          return `${className}_serializer()`;
        } else {
          const packageAlias = modulePathToAlias(recordLocation.modulePath);
          return `${packageAlias}.${className}_serializer()`;
        }
      }
    }
  }
}
