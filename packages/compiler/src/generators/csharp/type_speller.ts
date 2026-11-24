import type {
  Field,
  RecordKey,
  RecordLocation,
  ResolvedType,
} from "skir-internal";
import { getTypeName, modulePathToNamespace } from "./naming.js";

/**
 * Transforms a type found in a `.skir` file into a C# type expression.
 */
export class TypeSpeller {
  constructor(
    readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    readonly modulePath: string,
  ) {}

  getCsharpType(type: ResolvedType): string {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const ns = modulePathToNamespace(recordLocation.modulePath);
        const className = getTypeName(recordLocation);
        return `global::${ns}.${className}`;
      }
      case "array": {
        const itemType = this.getCsharpType(type.item);
        return `global::System.Collections.Immutable.ImmutableArray<${itemType}>`;
      }
      case "optional": {
        const otherType = this.getCsharpType(type.other);
        return `${otherType}?`;
      }
      case "primitive": {
        const { primitive } = type;
        switch (primitive) {
          case "bool":
            return "bool";
          case "int32":
            return "int";
          case "int64":
            return "long";
          case "hash64":
            return "ulong";
          case "float32":
            return "float";
          case "float64":
            return "double";
          case "timestamp":
            return "global::System.DateTimeOffset";
          case "string":
            return "string";
          case "bytes":
            return "global::SkirClient.ImmutableBytes";
        }
      }
    }
  }

  getCsharpFieldType(field: Field): string {
    if (!field.type) {
      throw new Error("Cannot spell a C# field type for a field without type.");
    }

    if (field.isRecursive === "hard") {
      const otherType = this.getCsharpType(field.type);
      return `global::SkirClient.Recursive<${otherType}>`;
    }

    if (field.isRecursive === "via-optional") {
      if (field.type.kind !== "optional") {
        throw new Error(
          "via-optional recursive field must have an optional underlying type.",
        );
      }
      const otherType = this.getCsharpType(field.type.other);
      return `global::SkirClient.Recursive<${otherType}>?`;
    }

    return this.getCsharpType(field.type);
  }

  getFieldDefaultExpr(field: Field): string {
    if (!field.type) {
      throw new Error(
        "Cannot spell a C# field default expression for a field without type.",
      );
    }

    if (field.isRecursive === "hard") {
      const fieldType = this.getCsharpFieldType(field);
      return `${fieldType}.Default`;
    }

    if (field.isRecursive === "via-optional") {
      return "null";
    }

    return this.getDefaultExpr(field.type);
  }

  getDefaultExpr(type: ResolvedType): string {
    switch (type.kind) {
      case "record": {
        const csharpType = this.getCsharpType(type);
        const recordLocation = this.recordMap.get(type.key)!;
        return recordLocation.record.recordType === "struct"
          ? `${csharpType}.Default`
          : `${csharpType}.Unknown`;
      }
      case "array": {
        const itemType = this.getCsharpType(type.item);
        return `global::System.Collections.Immutable.ImmutableArray<${itemType}>.Empty`;
      }
      case "optional": {
        return "null";
      }
      case "primitive": {
        const { primitive } = type;
        switch (primitive) {
          case "bool":
            return "false";
          case "int32":
            return "0";
          case "int64":
            return "0L";
          case "hash64":
            return "0UL";
          case "float32":
            return "0.0f";
          case "float64":
            return "0.0";
          case "timestamp":
            return "default(global::System.DateTimeOffset)";
          case "string":
            return '""';
          case "bytes":
            return "global::SkirClient.ImmutableBytes.Empty";
        }
      }
    }
  }

  /**
   * Returns a C# expression for the serializer of `type`.
   * In `initCtx` (called from _initAdapter), struct/enum types return their `_adapter`
   * field directly rather than calling `.Serializer` (which would trigger init recursively).
   */
  getSerializerExpr(
    type: ResolvedType,
    initCtx?: "init",
    isRecursive: false | "soft" | "via-optional" | "hard" = false,
  ): string {
    if (isRecursive === "hard") {
      // Property type is Recursive<T>. Wrap the inner serializer.
      const innerExpr = this.getSerializerExprInner(type, initCtx);
      return `global::SkirClient.Serializers.Recursive(${innerExpr})`;
    }
    if (isRecursive === "via-optional") {
      // Property type is Recursive<T>?. type is optional(T).
      if (type.kind !== "optional") {
        throw new Error(
          "via-optional recursive field must have an optional underlying type.",
        );
      }
      const innerExpr = this.getSerializerExprInner(type.other, initCtx);
      return `global::SkirClient.Serializers.OptionalValue(global::SkirClient.Serializers.Recursive(${innerExpr}))`;
    }
    return this.getSerializerExprInner(type, initCtx);
  }

  private getSerializerExprInner(type: ResolvedType, initCtx?: "init"): string {
    switch (type.kind) {
      case "primitive": {
        switch (type.primitive) {
          case "bool":
            return "global::SkirClient.Serializers.Bool";
          case "int32":
            return "global::SkirClient.Serializers.Int32";
          case "int64":
            return "global::SkirClient.Serializers.Int64";
          case "hash64":
            return "global::SkirClient.Serializers.Hash64";
          case "float32":
            return "global::SkirClient.Serializers.Float32";
          case "float64":
            return "global::SkirClient.Serializers.Float64";
          case "string":
            return "global::SkirClient.Serializers.String";
          case "timestamp":
            return "global::SkirClient.Serializers.Timestamp";
          case "bytes":
            return "global::SkirClient.Serializers.Bytes";
        }
        throw new Error(`Unknown primitive type: ${type.primitive}`);
      }
      case "record": {
        const loc = this.recordMap.get(type.key)!;
        const ns = modulePathToNamespace(loc.modulePath);
        const cname = getTypeName(loc);
        const fqn = `global::${ns}.${cname}`;
        if (initCtx === "init" && loc.modulePath === this.modulePath) {
          return `ModuleInit_.${cname}_Serializer`;
        }
        return `${fqn}.Serializer`;
      }
      case "array": {
        const itemExpr = this.getSerializerExprInner(type.item, initCtx);
        const keyExtractor = this.getArrayKeyExtractor(type);
        return keyExtractor.length > 0
          ? `global::SkirClient.Serializers.Array(${itemExpr}, keyExtractor: ${JSON.stringify(keyExtractor)})`
          : `global::SkirClient.Serializers.Array(${itemExpr})`;
      }
      case "optional": {
        const inner = type.other;
        const innerExpr = this.getSerializerExprInner(inner, initCtx);
        // Determine if inner type is a value type (struct/primitive) or ref type (enum/string).
        // ImmutableArray<T> is a struct, so arrays are also value types.
        const isValueType =
          inner.kind === "array" ||
          (inner.kind === "record" &&
            this.recordMap.get(inner.key)!.record.recordType === "struct") ||
          (inner.kind === "primitive" && inner.primitive !== "string");
        return isValueType
          ? `global::SkirClient.Serializers.OptionalValue(${innerExpr})`
          : `global::SkirClient.Serializers.Optional(${innerExpr})`;
      }
    }

    throw new Error(
      `Unsupported type kind: ${(type as { kind: string }).kind}`,
    );
  }

  private getArrayKeyExtractor(
    type: Extract<ResolvedType, { kind: "array" }>,
  ): string {
    const maybeKey = (
      type as { key?: { path?: readonly { name?: { text?: string } }[] } }
    ).key;
    const path = maybeKey?.path;
    if (!path || path.length === 0) {
      return "";
    }
    const names = path
      .map((item) => item?.name?.text ?? "")
      .filter((name) => name.length > 0);
    return names.join(".");
  }
}
