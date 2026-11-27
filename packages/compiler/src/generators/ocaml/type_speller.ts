import type {
  Field,
  Module,
  RecordKey,
  RecordLocation,
  ResolvedType,
} from "skir-internal";
import {
  getFlatRecordId,
  getInternalTypeName,
  getSubmodulePath,
  modulePathToOcamlModuleName,
} from "./naming.js";

export class TypeSpeller {
  constructor(
    readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    readonly inModule: Module,
  ) {}

  /**
   * Spells the type using the internal top-level `rec__<flat>_` alias for
   * same-module records (so it is valid anywhere in the file, including before
   * or inside submodules) and `ExternalMod.Submod.t` for cross-module records.
   */
  getOcamlType(type: ResolvedType, usePublicSubmoduleForLocal = false): string {
    switch (type.kind) {
      case "record": {
        const loc = this.recordMap.get(type.key)!;
        if (loc.modulePath === this.inModule.path) {
          return usePublicSubmoduleForLocal
            ? `${getSubmodulePath(loc)}.t`
            : getInternalTypeName(loc);
        }
        return `${modulePathToOcamlModuleName(loc.modulePath)}.${getSubmodulePath(loc)}.t`;
      }
      case "array": {
        const itemType = this.getOcamlType(
          type.item,
          usePublicSubmoduleForLocal,
        );
        return `${itemType} list`;
      }
      case "optional": {
        const otherType = this.getOcamlType(
          type.other,
          usePublicSubmoduleForLocal,
        );
        return `${otherType} option`;
      }
      case "primitive": {
        switch (type.primitive) {
          case "bool":
            return "bool";
          case "int32":
            return "int32";
          case "int64":
          case "hash64":
            return "int64";
          case "float32":
          case "float64":
            return "float";
          case "timestamp":
            return "Skir_.Timestamp.t";
          case "string":
          case "bytes":
            return "string";
        }
      }
    }
  }

  getFieldOcamlType(field: Field, usePublicSubmoduleForLocal = false): string {
    const base = this.getOcamlType(field.type!, usePublicSubmoduleForLocal);
    if (field.isRecursive === "hard") {
      return `${base} Skir_.recursive`;
    }
    return base;
  }

  getDefaultExpression(type: ResolvedType, lazyForLocalRecord = false): string {
    switch (type.kind) {
      case "record": {
        const loc = this.recordMap.get(type.key)!;
        if (loc.modulePath === this.inModule.path) {
          const flat = getFlatRecordId(loc);
          return lazyForLocalRecord
            ? `(Lazy_.force default__${flat}_lazy_)`
            : `default__${flat}_`;
        }
        const defaultName =
          loc.record.recordType === "enum" ? "unknown" : "default";
        return `${modulePathToOcamlModuleName(loc.modulePath)}.${getSubmodulePath(loc)}.${defaultName}`;
      }
      case "array":
        return "[]";
      case "optional":
        return "None";
      case "primitive": {
        switch (type.primitive) {
          case "bool":
            return "false";
          case "int32":
            return "0l";
          case "int64":
          case "hash64":
            return "0L";
          case "float32":
          case "float64":
            return "0.0";
          case "timestamp":
            return "Skir_.Timestamp.unix_epoch";
          case "string":
          case "bytes":
            return '""';
        }
      }
    }
  }

  getFieldDefaultExpression(field: Field, lazyForLocalRecord = false): string {
    if (field.isRecursive === "hard") {
      return "Skir_.Default";
    }
    return this.getDefaultExpression(field.type!, lazyForLocalRecord);
  }

  getSerializerExpression(type: ResolvedType): string {
    switch (type.kind) {
      case "record": {
        const loc = this.recordMap.get(type.key)!;
        if (loc.modulePath === this.inModule.path) {
          return `serializer__${getFlatRecordId(loc)}_ ()`;
        }
        return `${modulePathToOcamlModuleName(loc.modulePath)}.${getSubmodulePath(loc)}.serializer ()`;
      }
      case "array": {
        const itemSer = this.getSerializerExpression(type.item);
        if (type.key) {
          const keyExtractor = JSON.stringify(
            type.key.path.map((p) => p.name.text).join("."),
          );
          return `Skir_.keyed_list_serializer (${itemSer}) ~key_extractor:${keyExtractor}`;
        }
        return `Skir_.list_serializer (${itemSer})`;
      }
      case "optional": {
        const otherSer = this.getSerializerExpression(type.other);
        return `Skir_.optional_serializer (${otherSer})`;
      }
      case "primitive": {
        switch (type.primitive) {
          case "bool":
            return "Skir_.bool_serializer";
          case "int32":
            return "Skir_.int32_serializer";
          case "int64":
            return "Skir_.int64_serializer";
          case "hash64":
            return "Skir_.hash64_serializer";
          case "float32":
            return "Skir_.float32_serializer";
          case "float64":
            return "Skir_.float64_serializer";
          case "timestamp":
            return "Skir_.timestamp_serializer";
          case "string":
            return "Skir_.string_serializer";
          case "bytes":
            return "Skir_.bytes_serializer";
        }
      }
    }
  }

  getFieldSerializerExpression(field: Field): string {
    if (field.isRecursive === "hard") {
      return `Skir_.recursive_serializer (fun () -> ${this.getSerializerExpression(field.type!)})`;
    }
    return this.getSerializerExpression(field.type!);
  }
}
