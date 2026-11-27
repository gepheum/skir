import type {
  Field,
  RecordKey,
  RecordLocation,
  ResolvedType,
} from "skir-internal";
import { getTypeName, modulePathToFsharpModuleName } from "./naming.js";

/**
 * Transforms a type found in a `.skir` file into an F# type expression.
 */
export class TypeSpeller {
  constructor(
    readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    readonly modulePath: string,
  ) {}

  getFsharpType(type: ResolvedType): string {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const modName = modulePathToFsharpModuleName(recordLocation.modulePath);
        const typeName = getTypeName(recordLocation);
        if (recordLocation.modulePath === this.modulePath) {
          return typeName;
        }
        return `${modName}.${typeName}`;
      }
      case "array": {
        const itemType = this.getFsharpType(type.item);
        return `global.System.Collections.Immutable.ImmutableArray<${itemType}>`;
      }
      case "optional": {
        const otherType = this.getFsharpType(type.other);
        return `option<${otherType}>`;
      }
      case "primitive": {
        const { primitive } = type;
        switch (primitive) {
          case "bool":
            return "bool";
          case "int32":
            return "int";
          case "int64":
            return "int64";
          case "hash64":
            return "uint64";
          case "float32":
            return "float32";
          case "float64":
            return "float";
          case "timestamp":
            return "global.System.DateTimeOffset";
          case "string":
            return "string";
          case "bytes":
            return "global.SkirClient.ImmutableBytes";
        }
      }
    }
  }

  getFsharpFieldType(field: Field): string {
    if (!field.type) {
      throw new Error(
        "Cannot spell an F# field type for a field without type.",
      );
    }

    if (field.isRecursive === "hard") {
      const otherType = this.getFsharpType(field.type);
      return `global.SkirClient.Recursive<${otherType}>`;
    }

    if (field.isRecursive === "via-optional") {
      if (field.type.kind !== "optional") {
        throw new Error(
          "via-optional recursive field must have an optional underlying type.",
        );
      }
      const otherType = this.getFsharpType(field.type.other);
      return `option<global.SkirClient.Recursive<${otherType}>>`;
    }

    return this.getFsharpType(field.type);
  }

  getFieldDefaultExpr(field: Field): string {
    if (!field.type) {
      throw new Error(
        "Cannot spell an F# field default expression for a field without type.",
      );
    }

    if (field.isRecursive === "hard") {
      const otherType = this.getFsharpType(field.type);
      return `global.SkirClient.Recursive<${otherType}>.Default`;
    }

    if (field.isRecursive === "via-optional") {
      return "None";
    }

    return this.getDefaultExpr(field.type);
  }

  getDefaultExpr(type: ResolvedType): string {
    switch (type.kind) {
      case "record": {
        const fsharpType = this.getFsharpType(type);
        const recordLocation = this.recordMap.get(type.key)!;
        return recordLocation.record.recordType === "struct"
          ? `${fsharpType}.Default`
          : `${fsharpType}.UnknownDefault`;
      }
      case "array": {
        const itemType = this.getFsharpType(type.item);
        return `global.System.Collections.Immutable.ImmutableArray<${itemType}>.Empty`;
      }
      case "optional": {
        return "None";
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
            return "global.System.DateTimeOffset.UnixEpoch";
          case "string":
            return '""';
          case "bytes":
            return "global.SkirClient.ImmutableBytes.Empty";
        }
      }
    }
  }

  /**
   * Returns an F# expression that checks equality between `a` and `b` of type `type`,
   * handling `ImmutableArray<T>` element-wise (since `.NET ImmutableArray<T>.Equals`
   * only checks reference equality of the backing array).
   */
  getValueEqualsExpr(type: ResolvedType, aExpr: string, bExpr: string): string {
    if (type.kind === "array") {
      const itemType = this.getFsharpType(type.item);
      if (this.containsArray(type.item)) {
        const itemEq = this.getValueEqualsExpr(type.item, "x_", "y_");
        return `(if (${aExpr}).IsDefault && (${bExpr}).IsDefault then true elif (${aExpr}).IsDefault || (${bExpr}).IsDefault then false else (${aExpr}).Length = (${bExpr}).Length && global.System.Linq.Enumerable.All(global.System.Linq.Enumerable.Range(0, (${aExpr}).Length), fun i_ -> let x_ : ${itemType} = (${aExpr}).[i_] in let y_ : ${itemType} = (${bExpr}).[i_] in ${itemEq}))`;
      }
      return `(if (${aExpr}).IsDefault && (${bExpr}).IsDefault then true elif (${aExpr}).IsDefault || (${bExpr}).IsDefault then false else global.System.Linq.Enumerable.SequenceEqual(${aExpr}, ${bExpr}))`;
    }
    if (type.kind === "optional" && this.containsArray(type.other)) {
      const innerType = this.getFsharpType(type.other);
      const innerEq = this.getValueEqualsExpr(type.other, "va_", "vb_");
      return `(match (${aExpr}), (${bExpr}) with | None, None -> true | Some (va_ : ${innerType}), Some (vb_ : ${innerType}) -> ${innerEq} | _ -> false)`;
    }
    return `((${aExpr}) = (${bExpr}))`;
  }

  getFieldEqualsExpr(field: Field, aExpr: string, bExpr: string): string {
    if (!field.type) return "true";
    if (field.isRecursive === "hard" || field.isRecursive === "via-optional") {
      return `((${aExpr}) = (${bExpr}))`;
    }
    return this.getValueEqualsExpr(field.type, aExpr, bExpr);
  }

  /**
   * Returns an F# expression computing a hash code for `valExpr` of type `type`,
   * consistent with `getValueEqualsExpr`.
   */
  getValueHashExpr(type: ResolvedType, valExpr: string): string {
    if (type.kind === "array") {
      return `(if (${valExpr}).IsDefault then 0 else (${valExpr}).Length)`;
    }
    if (type.kind === "optional" && this.containsArray(type.other)) {
      return `(match (${valExpr}) with | None -> 0 | Some _ -> 1)`;
    }
    return `global.System.Collections.Generic.EqualityComparer.Default.GetHashCode(${valExpr})`;
  }

  getFieldHashExpr(field: Field, valExpr: string): string {
    if (!field.type) return "0";
    if (field.isRecursive === "hard" || field.isRecursive === "via-optional") {
      return `global.System.Collections.Generic.EqualityComparer.Default.GetHashCode(${valExpr})`;
    }
    return this.getValueHashExpr(field.type, valExpr);
  }

  private containsArray(type: ResolvedType): boolean {
    if (type.kind === "array") return true;
    if (type.kind === "optional") return this.containsArray(type.other);
    return false;
  }

  getSerializerExpr(
    type: ResolvedType,
    initCtx?: "init",
    isRecursive: false | "soft" | "via-optional" | "hard" = false,
  ): string {
    if (isRecursive === "hard") {
      const innerExpr = this.getSerializerExprInner(type, initCtx);
      return `global.SkirClient.Serializers.Recursive(${innerExpr})`;
    }
    if (isRecursive === "via-optional") {
      if (type.kind !== "optional") {
        throw new Error(
          "via-optional recursive field must have an optional underlying type.",
        );
      }
      const innerType = this.getFsharpType(type.other);
      const recType = `global.SkirClient.Recursive<${innerType}>`;
      const innerExpr = `global.SkirClient.Serializers.Recursive(${this.getSerializerExprInner(type.other, initCtx)})`;
      return this.wrapOptionalCustomSerializer(recType, innerExpr);
    }
    return this.getSerializerExprInner(type, initCtx);
  }

  private wrapOptionalCustomSerializer(
    innerFsharpType: string,
    innerSerExpr: string,
  ): string {
    return `global.SkirClient.Serializers.OptionalCustom<${innerFsharpType}, option<${innerFsharpType}>>(${innerSerExpr}, None, global.System.Func<${innerFsharpType}, option<${innerFsharpType}>>(Some), global.System.Func<option<${innerFsharpType}>, bool>(Option.isNone), global.System.Func<option<${innerFsharpType}>, ${innerFsharpType}>(Option.get))`;
  }

  private getSerializerExprInner(type: ResolvedType, initCtx?: "init"): string {
    switch (type.kind) {
      case "primitive": {
        switch (type.primitive) {
          case "bool":
            return "global.SkirClient.Serializers.Bool";
          case "int32":
            return "global.SkirClient.Serializers.Int32";
          case "int64":
            return "global.SkirClient.Serializers.Int64";
          case "hash64":
            return "global.SkirClient.Serializers.Hash64";
          case "float32":
            return "global.SkirClient.Serializers.Float32";
          case "float64":
            return "global.SkirClient.Serializers.Float64";
          case "string":
            return "global.SkirClient.Serializers.String";
          case "timestamp":
            return "global.SkirClient.Serializers.Timestamp";
          case "bytes":
            return "global.SkirClient.Serializers.Bytes";
        }
        throw new Error(`Unknown primitive type: ${type.primitive}`);
      }
      case "record": {
        const loc = this.recordMap.get(type.key)!;
        const modName = modulePathToFsharpModuleName(loc.modulePath);
        const typeName = getTypeName(loc);
        if (loc.modulePath === this.modulePath) {
          if (initCtx === "init") {
            return `ModuleInit_.${typeName}_Serializer`;
          }
          return `${typeName}.Serializer`;
        }
        return `${modName}.${typeName}.Serializer`;
      }
      case "array": {
        const itemExpr = this.getSerializerExprInner(type.item, initCtx);
        const keyExtractor = this.getArrayKeyExtractor(type);
        return keyExtractor.length > 0
          ? `global.SkirClient.Serializers.Array(${itemExpr}, keyExtractor = ${JSON.stringify(keyExtractor)})`
          : `global.SkirClient.Serializers.Array(${itemExpr})`;
      }
      case "optional": {
        const inner = type.other;
        const innerFsharpType = this.getFsharpType(inner);
        const innerExpr = this.getSerializerExprInner(inner, initCtx);
        return this.wrapOptionalCustomSerializer(innerFsharpType, innerExpr);
      }
    }
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
