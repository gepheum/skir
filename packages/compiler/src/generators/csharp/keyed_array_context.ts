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

export interface KeyedArraySpec {
  readonly specName: string;
  readonly fieldPath: FieldPath;
}

export class KeyedArrayContext {
  constructor(
    skirModules: readonly Module[],
    recordMap: ReadonlyMap<RecordKey, RecordLocation>,
  ) {
    const processType = (type: ResolvedType | undefined): void => {
      if (type?.kind !== "array" || !type.key) return;
      if (!keyTypeIsSupported(type.key.keyType, recordMap)) return;
      if (type.item.kind !== "record") {
        throw new TypeError("Expected keyed array item type to be a record");
      }

      const keyExtractor = type.key.path
        .map((part) => part.name.text)
        .join(".");
      const keyMap = this.recordKeyToKeyMap.get(type.item.key) ?? new Map();
      if (keyMap.size === 0) {
        this.recordKeyToKeyMap.set(type.item.key, keyMap);
      }
      keyMap.set(keyExtractor, type.key);
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

  getKeySpecsForItemStruct(struct: RecordLocation): readonly KeyedArraySpec[] {
    const keyMap = this.recordKeyToKeyMap.get(struct.record.key);
    if (!keyMap) {
      return [];
    }
    return [...keyMap.values()].map((fieldPath) => ({
      specName: getCsharpKeySpecSuffix(fieldPath),
      fieldPath,
    }));
  }

  getKeySpecForArrayType(
    type: Extract<ResolvedType, { kind: "array" }>,
  ): KeyedArraySpec | null {
    if (!type.key || type.item.kind !== "record") {
      return null;
    }

    const keyExtractor = type.key.path.map((part) => part.name.text).join(".");
    return (
      this.getKeySpecsForItemStructByKey(type.item.key).find(
        (spec) =>
          spec.fieldPath.path.map((part) => part.name.text).join(".") ===
          keyExtractor,
      ) ?? null
    );
  }

  private getKeySpecsForItemStructByKey(
    recordKey: RecordKey,
  ): readonly KeyedArraySpec[] {
    const keyMap = this.recordKeyToKeyMap.get(recordKey);
    if (!keyMap) {
      return [];
    }
    return [...keyMap.values()].map((fieldPath) => ({
      specName: getCsharpKeySpecSuffix(fieldPath),
      fieldPath,
    }));
  }

  private readonly recordKeyToKeyMap = new Map<
    RecordKey,
    Map<string, FieldPath>
  >();
}

export function keyTypeIsSupported(
  keyType: PrimitiveType | ResolvedRecordRef,
  recordMap: ReadonlyMap<RecordKey, RecordLocation>,
): boolean {
  if (keyType.kind === "record") {
    const keyRecord = recordMap.get(keyType.key);
    return keyRecord?.record.recordType === "enum";
  }
  return (
    keyType.primitive !== "float32" &&
    keyType.primitive !== "float64" &&
    keyType.primitive !== "bytes"
  );
}

export function getCsharpKeySpecSuffix(fieldPath: FieldPath): string {
  return "By_".concat(
    fieldPath.path
      .map((part) => convertCase(part.name.text, "UpperCamel"))
      .join("_"),
  );
}
