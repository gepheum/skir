import {
  convertCase,
  type FieldPath,
  type Module,
  type PrimitiveType,
  type RecordKey,
  type ResolvedRecordRef,
  type ResolvedType,
  type Record as SkirRecord,
} from "skir-internal";
import { toStructFieldName } from "./naming.js";
import { TypeSpeller } from "./type_speller.js";

export interface KeySpec {
  readonly moonbitTypeSuffix: string;
  readonly moonbitKeyType: string;
  readonly moonbitKeyExpr: string;
  readonly keyExtractor: string;
}

export class KeyedArrayContext {
  constructor(skirModules: readonly Module[]) {
    const { enumsUsedAsKeys, recordKeyToKeyMap } = this;
    const processType = (type: ResolvedType | undefined): void => {
      switch (type?.kind) {
        case "array":
          break;
        case "optional":
          processType(type.other);
          return;
        default:
          return;
      }

      if (!type.key) {
        return;
      }

      const { keyType } = type.key;
      if (!keyTypeIsSupported(keyType)) {
        return;
      }

      const keySpec = type.key.path.map((part) => part.name.text).join(".");
      const { item } = type;
      if (item.kind !== "record") {
        throw new TypeError("Expected keyed-array item type to be a record");
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
    struct: SkirRecord,
    typeSpeller: TypeSpeller,
  ): readonly KeySpec[] {
    const keyMap = this.recordKeyToKeyMap.get(struct.key);
    return keyMap
      ? [...keyMap.values()].map((fieldPath) => {
          const moonbitTypeSuffix = getMoonbitKeyTypeSuffix(fieldPath);
          const keyTypeIsRecord = fieldPath.keyType.kind === "record";
          let moonbitKeyType = typeSpeller.getMoonbitType(fieldPath.keyType);
          const moonbitKeyExpr = "item.".concat(
            fieldPath.path
              .map((p, i) => {
                const isLast = i === fieldPath.path.length - 1;
                if (keyTypeIsRecord && isLast && p.name.text === "kind") {
                  return "kind()";
                }
                return toStructFieldName(p.name.text);
              })
              .join("."),
          );
          if (keyTypeIsRecord) {
            moonbitKeyType = moonbitKeyType.concat("_kind");
          }

          return {
            moonbitTypeSuffix,
            moonbitKeyType,
            moonbitKeyExpr,
            keyExtractor: fieldPath.path.map((p) => p.name.text).join("."),
          };
        })
      : [];
  }

  isEnumUsedAsKey(enumType: SkirRecord): boolean {
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

function getMoonbitKeyTypeSuffix(fieldPath: FieldPath): string {
  return "_by".concat(
    fieldPath.path.map((p) => convertCase(p.name.text, "UpperCamel")).join("_"),
  );
}
