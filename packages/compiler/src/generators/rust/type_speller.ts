import type { RecordKey, RecordLocation, ResolvedType } from "skir-internal";
import {
  getRustKeySpecSuffix,
  keyTypeIsSupported,
} from "./keyed_array_context.js";
import { getTypeName, Namer, toRustPathPrefix } from "./naming.js";

/**
 * Transforms a type found in a `.skir` file into a Rust type.
 */
export class TypeSpeller {
  constructor(
    readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    readonly namer: Namer,
  ) {}

  getRustType(
    type: ResolvedType,
    fieldRecursivity?: false | "soft" | "via-optional" | "hard",
  ): string {
    switch (type.kind) {
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const className = getTypeName(recordLocation);
        let recordType: string;
        if (recordLocation.modulePath === this.namer.skirModule?.path) {
          recordType = className;
        } else {
          const rustPathPrefix = toRustPathPrefix(recordLocation.modulePath);
          recordType = `${rustPathPrefix}::${className}`;
        }
        return fieldRecursivity === "hard"
          ? `${this.namer.option}<${this.namer.box}<${recordType}>>`
          : recordType;
      }
      case "array": {
        const itemType = this.getRustType(type.item);
        if (type.key && keyTypeIsSupported(type.key.keyType)) {
          const suffix = getRustKeySpecSuffix(type.key);
          return `crate::skir_client::KeyedVec<${itemType}${suffix}>`;
        } else {
          return `${this.namer.vec}<${itemType}>`;
        }
      }
      case "optional": {
        let otherType = this.getRustType(type.other);
        if (fieldRecursivity === "via-optional") {
          otherType = `${this.namer.box}<${otherType}>`;
        }
        return `${this.namer.option}<${otherType}>`;
      }
      case "primitive": {
        const { primitive } = type;
        switch (primitive) {
          case "bool":
            return "bool";
          case "int32":
            return "i32";
          case "int64":
            return "i64";
          case "float32":
            return "f32";
          case "float64":
            return "f64";
          case "string":
            return this.namer.string;
          case "hash64":
            return "u64";
          case "timestamp":
            return "std::time::SystemTime";
          case "bytes":
            return this.namer.vec.concat("<u8>");
        }
      }
    }
  }

  getDefaultExpr(type: ResolvedType): string {
    switch (type.kind) {
      case "record": {
        const rustType = this.getRustType(type);
        return `${rustType}::default()`;
      }
      case "array": {
        if (type.key && keyTypeIsSupported(type.key.keyType)) {
          return "crate::skir_client::KeyedVec::default()";
        } else {
          return this.namer.vec.concat("::default()");
        }
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
            return "0_i32";
          case "int64":
            return "0_i64";
          case "float32":
            return "0.0_f32";
          case "float64":
            return "0.0_f64";
          case "string":
            return this.namer.string.concat("::new()");
          case "hash64":
            return "0_u64";
          case "timestamp":
            return "::std::time::SystemTime::UNIX_EPOCH";
          case "bytes":
            return this.namer.vec.concat("::default()");
        }
      }
    }
  }

  getTypeName(recordKey: RecordKey): string {
    const record = this.recordMap.get(recordKey)!;
    return getTypeName(record);
  }

  getSerializerExpression(
    type: ResolvedType,
    context: "init" | null,
    fieldRecursivity?: false | "soft" | "via-optional" | "hard",
  ): string {
    switch (type.kind) {
      case "primitive": {
        switch (type.primitive) {
          case "bool":
            return "crate::skir_client::Serializer::bool()";
          case "int32":
            return "crate::skir_client::Serializer::int32()";
          case "int64":
            return "crate::skir_client::Serializer::int64()";
          case "hash64":
            return "crate::skir_client::Serializer::hash64()";
          case "float32":
            return "crate::skir_client::Serializer::float32()";
          case "float64":
            return "crate::skir_client::Serializer::float64()";
          case "timestamp":
            return "crate::skir_client::Serializer::timestamp()";
          case "string":
            return "crate::skir_client::Serializer::string()";
          case "bytes":
            return "crate::skir_client::Serializer::bytes()";
        }
        const _: never = type.primitive;
        throw TypeError();
      }
      case "array": {
        const itemType = this.getRustType(type.item);
        const itemSerializer = this.getSerializerExpression(type.item, context);
        if (type.key && keyTypeIsSupported(type.key.keyType)) {
          const suffix = getRustKeySpecSuffix(type.key);
          return `crate::skir_client::Serializer::<crate::skir_client::KeyedVec<${itemType}${suffix}>>::keyed_array(${itemSerializer})`;
        } else {
          return `crate::skir_client::Serializer::array(${itemSerializer})`;
        }
      }
      case "optional": {
        const otherSerializer = this.getSerializerExpression(
          type.other,
          context,
        );
        if (fieldRecursivity === "via-optional") {
          return `crate::skir_client::internal::option_box_serializer(${otherSerializer})`;
        } else {
          return `crate::skir_client::Serializer::optional(${otherSerializer})`;
        }
      }
      case "record": {
        const recordLocation = this.recordMap.get(type.key)!;
        const rustType = this.getRustType(type);
        let serializerExpr: string;
        if (
          context === "init" &&
          recordLocation.modulePath === this.namer.skirModule?.path
        ) {
          const fnName =
            recordLocation.record.recordType === "struct"
              ? "struct_serializer_from_static"
              : "enum_serializer_from_static";
          serializerExpr = `crate::skir_client::internal::${fnName}(${rustType}::_adapter())`;
        } else {
          serializerExpr = rustType.concat("::serializer()");
        }
        return fieldRecursivity === "hard"
          ? `crate::skir_client::internal::recursive_serializer(${serializerExpr})`
          : serializerExpr;
      }
    }
  }
}

export function skirDefaultIsRustDefault(type: ResolvedType): boolean {
  switch (type.kind) {
    case "record":
    case "array":
      return true;
    case "optional":
      return skirDefaultIsRustDefault(type.other);
    case "primitive": {
      const { primitive } = type;
      switch (primitive) {
        case "timestamp":
          return false;
        default:
          return true;
      }
    }
  }
}
