import type { RecordKey, RecordLocation, ResolvedType } from "skir-internal";
import { getSpecName, keyTypeIsSupported } from "./keyed_array_context.js";
import { getTypeRef, ModuleContext } from "./naming.js";

/**
 * Transforms a type found in a `.skir` file into a Swift type.
 */
export class TypeSpeller {
  constructor(readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>) {}

  getSwiftType(
    type: ResolvedType,
    context: RecordLocation | ModuleContext | null,
    fieldRecursivity?: false | "soft" | "via-optional" | "hard",
  ): string {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const typeRef = getTypeRef(recordLocation, context);
        return fieldRecursivity === "hard"
          ? `SkirClient.IndirectOptional<${typeRef}>`
          : typeRef;
      }
      case "array": {
        const itemType = this.getSwiftType(type.item, context);
        if (type.key && keyTypeIsSupported(type.key.keyType)) {
          const specName = getSpecName(type.key);
          return `SkirClient.KeyedArray<${itemType}.${specName}>`;
        } else {
          return `[${itemType}]`;
        }
      }
      case "optional": {
        const otherType = this.getSwiftType(type.other, context);
        return fieldRecursivity === "via-optional"
          ? `SkirClient.IndirectOptional<${otherType}>`
          : `${otherType}?`;
      }
      case "primitive": {
        const { primitive } = type;
        switch (primitive) {
          case "bool":
            return "Bool";
          case "int32":
            return "Int32";
          case "int64":
            return "Int64";
          case "float32":
            return "Float";
          case "float64":
            return "Double";
          case "string":
            return "String";
          case "hash64":
            return "UInt64";
          case "timestamp":
            return "Foundation.Date";
          case "bytes":
            return "Foundation.Data";
        }
      }
    }
  }

  getSerializerExpression(
    type: ResolvedType,
    context: RecordLocation | ModuleContext | null,
    init?: "init",
    fieldRecursivity?: false | "soft" | "via-optional" | "hard",
  ): string {
    let result: string;
    switch (type.kind) {
      case "primitive": {
        switch (type.primitive) {
          case "bool":
            result = "SkirClient.Serializers.bool";
            break;
          case "int32":
            result = "SkirClient.Serializers.int32";
            break;
          case "int64":
            result = "SkirClient.Serializers.int64";
            break;
          case "hash64":
            result = "SkirClient.Serializers.hash64";
            break;
          case "float32":
            result = "SkirClient.Serializers.float32";
            break;
          case "float64":
            result = "SkirClient.Serializers.float64";
            break;
          case "timestamp":
            result = "SkirClient.Serializers.timestamp";
            break;
          case "string":
            result = "SkirClient.Serializers.string";
            break;
          case "bytes":
            result = "SkirClient.Serializers.bytes";
            break;
          default: {
            const _: never = type.primitive;
            throw TypeError();
          }
        }
        break;
      }
      case "array": {
        const itemSerializer = this.getSerializerExpression(
          type.item,
          context,
          init,
        );
        if (type.key && keyTypeIsSupported(type.key.keyType)) {
          result =
            `SkirClient.Serializers.keyedArray(\n` + itemSerializer + "\n)";
        } else {
          result = `SkirClient.Serializers.array(\n` + itemSerializer + "\n)";
        }
        break;
      }
      case "optional": {
        result =
          `SkirClient.Serializers.optional(\n` +
          this.getSerializerExpression(type.other, context, init) +
          "\n)";
        break;
      }
      case "record": {
        const typeRef = getTypeRef(this.recordMap.get(type.key)!, context);
        if (init) {
          result = `SkirClient.Serializer(adapter: ${typeRef}._typeAdapter)`;
        } else {
          result = `${typeRef}.serializer`;
        }
        break;
      }
    }

    if (fieldRecursivity === "hard") {
      return `SkirClient.Internal.recursiveSerializer(\n${result}\n)`;
    }
    if (fieldRecursivity === "via-optional") {
      return `SkirClient.Internal.indirectOptionalSerializer(\n${result}\n)`;
    }
    return result;
  }

  getDefaultExpression(
    type: ResolvedType,
    context: RecordLocation | ModuleContext,
    fieldRecursivity?: false | "soft" | "via-optional" | "hard",
  ): string {
    switch (type.kind) {
      case "primitive": {
        switch (type.primitive) {
          case "bool":
            return "false";
          case "int32":
          case "int64":
          case "hash64":
          case "float32":
          case "float64":
            return "0";
          case "string":
            return '""';
          case "timestamp":
            return "Foundation.Date(timeIntervalSince1970: 0)";
          case "bytes":
            return "Foundation.Data()";
        }
        const _: never = type.primitive;
        throw TypeError();
      }
      case "array": {
        return "[]";
      }
      case "optional": {
        return "nil";
      }
      case "record": {
        if (fieldRecursivity === "hard") {
          return "nil";
        } else {
          const { recordType } = this.recordMap.get(type.key)!.record;
          return recordType === "struct" ? ".defaultValue" : ".unknownValue";
        }
      }
    }
  }
}
