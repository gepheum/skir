import {
  convertCase,
  type FieldPath,
  type Module,
  type PrimitiveType,
  type RecordKey,
  type RecordLocation,
  type ResolvedRecordRef,
  type ResolvedType,
} from "skir-internal";
import {
  getTypeName,
  modulePathToImportAlias,
  toStructFieldName,
} from "./naming.js";
import type { TypeSpeller } from "./type_speller.js";

export interface KeySpec {
  readonly specName: string;
  readonly specRef: string;
  readonly valueType: string;
  readonly zigKeyType: string;
  readonly zigKeyExpr: string;
  readonly keyExtractor: string;
}

export class KeyedArrayContext {
  constructor(skirModules: readonly Module[]) {
    const processType = (type: ResolvedType | undefined): void => {
      if (type?.kind !== "array" || !type.key) return;
      if (!keyTypeIsSupported(type.key.keyType)) return;
      if (type.item.kind !== "record") {
        throw new TypeError("Expected keyed array item type to be a record");
      }

      const keyExtractor = type.key.path
        .map((part) => part.name.text)
        .join(".");
      const keyMap =
        this.recordKeyToKeyMap.get(type.item.key) ??
        new Map<string, FieldPath>();
      if (keyMap.size === 0) {
        this.recordKeyToKeyMap.set(type.item.key, keyMap);
      }
      keyMap.set(keyExtractor, type.key);
      if (type.key.keyType.kind === "record") {
        this.enumsUsedAsKeys.add(type.key.keyType.key);
      }
    };

    for (const skirModule of skirModules) {
      for (const record of skirModule.records) {
        for (const field of record.record.fields) {
          processType(field.type);
        }
      }
      for (const constant of skirModule.constants) {
        processType(constant.type);
      }
      for (const method of skirModule.methods) {
        processType(method.requestType);
        processType(method.responseType);
      }
    }
  }

  getKeySpecsForItemStruct(
    struct: RecordLocation,
    typeSpeller: TypeSpeller,
  ): readonly KeySpec[] {
    const keyMap = this.recordKeyToKeyMap.get(struct.record.key);
    if (!keyMap) {
      return [];
    }

    const fullTypeName = getTypeName(struct);
    const typeRef =
      struct.modulePath === typeSpeller.modulePath
        ? `_this_file.${fullTypeName}`
        : `${modulePathToImportAlias(struct.modulePath)}.${fullTypeName}`;
    return [...keyMap.values()].map((fieldPath) => {
      const specName = getZigKeySpecSuffix(fieldPath);
      let zigKeyExpr = "item.".concat(
        fieldPath.path
          .map((part) =>
            toStructFieldName(part.name.text).concat(
              part.declaration?.isRecursive ? "()" : "",
            ),
          )
          .join("."),
      );
      if (fieldPath.keyType.kind === "record") {
        zigKeyExpr = zigKeyExpr.concat(".kind()");
      }

      return {
        specName,
        specRef: `${typeRef}.${specName}`,
        valueType: typeRef,
        zigKeyType: typeSpeller.getKeyType(fieldPath.keyType),
        zigKeyExpr,
        keyExtractor: fieldPath.path.map((part) => part.name.text).join("."),
      };
    });
  }

  getKeySpecForArrayType(
    type: Extract<ResolvedType, { kind: "array" }>,
    typeSpeller: TypeSpeller,
  ): KeySpec | null {
    if (!type.key || type.item.kind !== "record") {
      return null;
    }

    const keyExtractor = type.key.path.map((part) => part.name.text).join(".");
    return (
      this.getKeySpecsForItemStruct(
        typeSpeller.recordMap.get(type.item.key)!,
        typeSpeller,
      ).find((spec) => spec.keyExtractor === keyExtractor) ?? null
    );
  }

  isEnumUsedAsKey(enumType: RecordLocation["record"]): boolean {
    return this.enumsUsedAsKeys.has(enumType.key);
  }

  private readonly recordKeyToKeyMap = new Map<
    RecordKey,
    Map<string, FieldPath>
  >();
  private readonly enumsUsedAsKeys = new Set<RecordKey>();
}

export function keyTypeIsSupported(
  keyType: PrimitiveType | ResolvedRecordRef,
): boolean {
  return (
    keyType.kind === "record" ||
    (keyType.primitive !== "float32" &&
      keyType.primitive !== "float64" &&
      keyType.primitive !== "bytes")
  );
}

export function getZigKeySpecSuffix(fieldPath: FieldPath): string {
  return "By_".concat(
    fieldPath.path
      .map((part) => convertCase(part.name.text, "UpperCamel"))
      .join("_"),
  );
}
