import type {
  ArrayType,
  Field,
  Module,
  PrimitiveType,
  RecordKey,
  RecordLocation,
  ResolvedRecordRef,
  ResolvedType,
} from "skir-internal";
import { convertCase } from "skir-internal";
import { getTypeName, modulePathToAlias } from "./naming.js";

export class TypeSpeller {
  constructor(
    readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    readonly inModule: Module,
  ) {}

  getMoonbitType(type: ResolvedType): string {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const typeName = getTypeName(recordLocation);
        if (recordLocation.modulePath === this.inModule.path) {
          return typeName;
        }
        return `@${modulePathToAlias(recordLocation.modulePath)}.${typeName}`;
      }
      case "array": {
        const maybeWrapperType = this.getMoonbitKeyedArrayWrapperType(type);
        if (maybeWrapperType) {
          return maybeWrapperType;
        }
        const itemType = this.getMoonbitType(type.item);
        return `@client.ImmutVector[${itemType}]`;
      }
      case "optional": {
        const otherType = this.getMoonbitType(type.other);
        return `${otherType}?`;
      }
      case "primitive": {
        const { primitive } = type;
        switch (primitive) {
          case "bool":
            return this.getNativeOrBareType("NativeBool", "Bool");
          case "int32":
            return this.getNativeOrBareType("NativeInt", "Int");
          case "int64":
            return this.getNativeOrBareType("NativeInt64", "Int64");
          case "hash64":
            return this.getNativeOrBareType("NativeUInt64", "UInt64");
          case "float32":
            return this.getNativeOrBareType("NativeFloat", "Float");
          case "float64":
            return this.getNativeOrBareType("NativeDouble", "Double");
          case "timestamp":
            return "@client.Timestamp";
          case "string":
            return this.getNativeOrBareType("NativeString", "String");
          case "bytes":
            return this.getNativeOrBareType("NativeBytes", "Bytes");
        }
      }
    }
  }

  getMoonbitFieldType(field: Field): string {
    const type = this.getRequiredFieldType(field);
    const moonbitType = this.getMoonbitType(type);
    if (field.isRecursive === "hard") {
      return `@client.Recursive[${moonbitType}]`;
    }
    return moonbitType;
  }

  getMoonbitFieldDefault(field: Field): string {
    if (field.isRecursive === "hard") {
      return "@client.Recursive::Default";
    }
    return this.getMoonbitDefault(this.getRequiredFieldType(field));
  }

  getMoonbitDefault(type: ResolvedType): string {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const typeName = getTypeName(recordLocation);
        const defaultMethod =
          recordLocation.record.recordType === "enum" ? "unknown" : "default";
        const defaultExpr = `${typeName}::${defaultMethod}()`;
        if (recordLocation.modulePath === this.inModule.path) {
          return defaultExpr;
        }
        return `@${modulePathToAlias(recordLocation.modulePath)}.${defaultExpr}`;
      }
      case "array": {
        const maybeWrapperType = this.getMoonbitKeyedArrayWrapperType(type);
        if (maybeWrapperType) {
          return `${maybeWrapperType}::empty()`;
        }
        return "@client.ImmutVector::new()";
      }
      case "optional":
        return "None";
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
          case "float64":
            return "0.0";
          case "timestamp":
            return "@client.Timestamp::unix_epoch()";
          case "string":
            return '""';
          case "bytes":
            return "Bytes::default()";
        }
      }
    }
  }

  getMoonbitSerializerExpr(type: ResolvedType): string {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const typeName = getTypeName(recordLocation);
        const serializerExpr = `${typeName}::serializer()`;
        if (recordLocation.modulePath === this.inModule.path) {
          return serializerExpr;
        }
        return `@${modulePathToAlias(recordLocation.modulePath)}.${serializerExpr}`;
      }
      case "array": {
        const itemSerializer = this.getMoonbitSerializerExpr(type.item);
        return `@client.vector_serializer(${itemSerializer})`;
      }
      case "optional": {
        const otherSerializer = this.getMoonbitSerializerExpr(type.other);
        return `@client.optional_serializer(${otherSerializer})`;
      }
      case "primitive": {
        switch (type.primitive) {
          case "bool":
            return "@client.bool_serializer()";
          case "int32":
            return "@client.int32_serializer()";
          case "int64":
            return "@client.int64_serializer()";
          case "hash64":
            return "@client.hash64_serializer()";
          case "float32":
            return "@client.float32_serializer()";
          case "float64":
            return "@client.float64_serializer()";
          case "timestamp":
            return "@client.timestamp_serializer()";
          case "string":
            return "@client.string_serializer()";
          case "bytes":
            return "@client.bytes_serializer()";
        }
      }
    }
  }

  private getRequiredFieldType(field: Field): ResolvedType {
    if (!field.type) {
      throw new Error("Expected field.type to be defined");
    }
    return field.type;
  }

  private getMoonbitKeyedArrayWrapperType(type: ArrayType): string | null {
    if (!type.key || type.item.kind !== "record") {
      return null;
    }
    if (!this.keyTypeIsSupported(type.key.keyType)) {
      return null;
    }

    const itemRecordLocation = this.recordMap.get(type.item.key)!;
    const itemTypeName = getTypeName(itemRecordLocation);
    const suffix = "_by".concat(
      type.key.path
        .map((p) => convertCase(p.name.text, "UpperCamel"))
        .join("_"),
    );
    const wrapperTypeName = `${itemTypeName}${suffix}`;
    if (itemRecordLocation.modulePath === this.inModule.path) {
      return wrapperTypeName;
    }
    return `@${modulePathToAlias(itemRecordLocation.modulePath)}.${wrapperTypeName}`;
  }

  private getNativeOrBareType(nativeName: string, bareName: string): string {
    return this.inModule.nameToDeclaration[bareName]
      ? `@client.${nativeName}`
      : bareName;
  }

  private keyTypeIsSupported(
    keyType: PrimitiveType | ResolvedRecordRef,
  ): boolean {
    return (
      keyType.kind === "record" ||
      (keyType.primitive !== "float32" &&
        keyType.primitive !== "float64" &&
        keyType.primitive !== "bytes")
    );
  }
}
