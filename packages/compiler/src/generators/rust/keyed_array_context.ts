import {
  convertCase,
  FieldPath,
  Module,
  PrimitiveType,
  Record,
  RecordKey,
  ResolvedRecordRef,
  ResolvedType,
} from "skir-internal";
import { toStructFieldName } from "./naming.js";
import { TypeSpeller } from "./type_speller.js";

export interface KeySpec {
  /** For example "Item_byId". */
  readonly rustSpecName: string;
  /** For example "i32", "Weekday_kind". */
  readonly rustKeyType: string;
  /** For example "item.id". */
  readonly rustKeyExpr: string;
  /** For example "id" or "sub_item.weekday.kind". */
  readonly keyExtractor: string;
  readonly lookupImpl: "CopyLookup" | "BorrowLookup";
}

export class KeyedArrayContext {
  constructor(skirModules: readonly Module[]) {
    const { enumsUsedAsKeys, recordKeyToKeyMap } = this;
    const processType = (type: ResolvedType | undefined): void => {
      if (type?.kind !== "array" || !type.key) return;
      const { keyType } = type.key;
      if (!keyTypeIsSupported(keyType)) return;
      const keySpec = type.key.path.map((part) => part.name.text).join(".");
      const { item } = type;
      if (item.kind !== "record") {
        throw new TypeError();
      }
      const keyMap =
        recordKeyToKeyMap.get(item.key) ?? new Map<string, FieldPath>();
      if (keyMap.size <= 0) {
        recordKeyToKeyMap.set(item.key, keyMap);
      }
      keyMap.set(keySpec, type.key);
      if (keyType.kind === "record") {
        enumsUsedAsKeys.add(keyType.key);
      }
    };
    for (const skirModule of skirModules) {
      for (const record of skirModule.records) {
        for (const field of record.record.fields) {
          processType(field.type);
        }
      }
      skirModule.constants.forEach((constant) => {
        processType(constant.type);
      });
      skirModule.methods.forEach((method) => {
        processType(method.requestType);
        processType(method.responseType);
      });
    }
  }

  getKeySpecsForItemStruct(
    struct: Record,
    typeSpeller: TypeSpeller,
  ): readonly KeySpec[] {
    const keyMap = this.recordKeyToKeyMap.get(struct.key);
    return keyMap
      ? [...keyMap.values()].map((fieldPath) => {
          const rustSpecName = typeSpeller
            .getTypeName(struct.key)
            .concat(getRustKeySpecSuffix(fieldPath));
          const { keyType } = fieldPath;
          const keyTypeIsString =
            keyType.kind === "primitive" && keyType.primitive === "string";
          let rustKeyType = typeSpeller.getRustType(keyType);
          let rustKeyExpr = "item.".concat(
            fieldPath.path
              .map((p) =>
                toStructFieldName(p.name.text).concat(
                  p.declaration?.isRecursive === "hard" ? "()" : "",
                ),
              )
              .join("."),
          );
          const keyExtractorParts = fieldPath.path.map((p) => p.name.text);
          if (fieldPath.keyType.kind === "record") {
            rustKeyType = rustKeyType.concat("_kind");
            // ".kind" -> ".kind()"
            rustKeyExpr = rustKeyExpr.concat("()");
          } else if (keyTypeIsString) {
            rustKeyExpr = rustKeyExpr.concat(".clone()");
          }
          return {
            rustSpecName: rustSpecName,
            rustKeyType: rustKeyType,
            rustKeyExpr: rustKeyExpr,
            keyExtractor: keyExtractorParts.join("."),
            lookupImpl: keyTypeIsString ? "BorrowLookup" : "CopyLookup",
          };
        })
      : [];
  }

  isEnumUsedAsKey(enumType: Record): boolean {
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
  // f32 and f64 don't implement Eq in Rust.
  // bytes is just a pain to deal with, and it's unlikely to be used as a
  // keyed array key.
  return (
    keyType.kind === "record" ||
    (keyType.primitive !== "float32" &&
      keyType.primitive !== "float64" &&
      keyType.primitive !== "bytes")
  );
}

export function getRustKeySpecSuffix(fieldPath: FieldPath): string {
  return "_by".concat(
    fieldPath.path.map((p) => convertCase(p.name.text, "UpperCamel")).join("_"),
  );
}
