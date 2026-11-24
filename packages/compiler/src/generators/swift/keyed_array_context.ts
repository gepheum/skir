import {
  convertCase,
  FieldPath,
  Module,
  PrimitiveType,
  Record,
  RecordKey,
  RecordLocation,
  ResolvedRecordRef,
  ResolvedType,
} from "skir-internal";
import { getSwiftFieldName } from "./naming.js";
import { TypeSpeller } from "./type_speller.js";

export interface KeySpec {
  /** For example "By_Id". */
  readonly specName: string;
  /** For example "Int32", "Enums_skir.Weekday._Kind". */
  readonly swiftKeyType: string;
  /** For example "subItem.weekday.kind". */
  readonly swiftKeyExpr: string;
  /** For example "id" or "sub_item.weekday.kind". */
  readonly keyExtractor: string;
  /** True when the original key type was a Skir enum/record. */
  readonly keyIsEnum: boolean;
}

export class KeyedArrayContext {
  constructor(skirModules: readonly Module[], typeSpeller: TypeSpeller) {
    const { enumsUsedAsKeys, recordKeyToKeySpecs } = this;
    const dedupKeyToSpec = new Map<RecordKey, Map<string, KeySpec>>();
    const processType = (type: ResolvedType | undefined): void => {
      if (type?.kind !== "array" || !type.key) return;
      const { keyType } = type.key;
      if (!keyTypeIsSupported(keyType)) return;
      const { item } = type;
      if (item.kind !== "record") {
        throw new TypeError();
      }
      const keyExtractor = type.key.path
        .map((part) => part.name.text)
        .join(".");
      const specName = getSpecName(type.key);
      const keyIsEnum = keyType.kind === "record";
      const swiftKeyType = keyIsEnum
        ? typeSpeller.getSwiftType(keyType, null).concat("._Kind")
        : typeSpeller.getSwiftType(keyType, null);
      const swiftKeyExpr = type.key.path
        .map((p) => getSwiftFieldName(p.name.text))
        .join(".");
      const keySpec: KeySpec = {
        specName: specName,
        swiftKeyType,
        swiftKeyExpr,
        keyExtractor,
        keyIsEnum,
      };
      const keyToSpec =
        dedupKeyToSpec.get(item.key) ?? new Map<string, KeySpec>();
      if (keyToSpec.size <= 0) {
        dedupKeyToSpec.set(item.key, keyToSpec);
      }
      keyToSpec.set(keyExtractor, keySpec);
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
    dedupKeyToSpec.forEach((keyToSpec, recordKey) => {
      recordKeyToKeySpecs.set(recordKey, [...keyToSpec.values()]);
    });
  }

  getKeySpecsForItemStruct(struct: RecordLocation): readonly KeySpec[] {
    return this.recordKeyToKeySpecs.get(struct.record.key) ?? [];
  }

  isEnumUsedAsKey(enumType: Record): boolean {
    return this.enumsUsedAsKeys.has(enumType.key);
  }

  private readonly recordKeyToKeySpecs = new Map<
    RecordKey,
    readonly KeySpec[]
  >();
  private readonly enumsUsedAsKeys = new Set<RecordKey>();
}

export function keyTypeIsSupported(
  keyType: PrimitiveType | ResolvedRecordRef,
): boolean {
  return keyType.kind === "record" || keyType.primitive !== "bytes";
}

export function getSpecName(fieldPath: FieldPath): string {
  return "By_".concat(
    fieldPath.path.map((p) => convertCase(p.name.text, "UpperCamel")).join("_"),
  );
}
