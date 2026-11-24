import { Module, RecordKey, RecordLocation, ResolvedType } from "skir-internal";

/**
 * Reorders the records in the module so that every record appears after its
 * non-recursive dependencies. A field contributes a structural dependency only
 * when it does NOT use `rec<T>` in C++, i.e. when
 * `field.isRecursive !== "hard" && field.isRecursive !== "via-optional"`.
 */
export function reorderRecords(
  module: Module,
  recordMap: ReadonlyMap<RecordKey, RecordLocation>,
): readonly RecordLocation[] {
  const sortedRecords = [...module.records].sort((a, b) => {
    const aKey = a.recordAncestors.map((r) => r.name).join(".");
    const bKey = b.recordAncestors.map((r) => r.name).join(".");
    return aKey.localeCompare(bKey, "en-US");
  });
  const recordToDeps = new Map<RecordKey, Set<RecordKey>>();
  for (const record of sortedRecords) {
    const recordDeps = new Set<RecordKey>();
    for (const field of record.record.fields) {
      if (
        !field.type ||
        field.isRecursive === "hard" ||
        field.isRecursive === "via-optional"
      ) {
        continue;
      }
      collectDirectDeps(field.type, module.path, recordMap, recordDeps);
    }
    recordToDeps.set(record.record.key, recordDeps);
  }
  const result: RecordLocation[] = [];
  const seenRecords = new Set<RecordKey>();
  function addRecord(record: RecordLocation): void {
    const { key } = record.record;
    if (seenRecords.has(key)) return;
    seenRecords.add(key);
    for (const dep of recordToDeps.get(key)!) {
      addRecord(recordMap.get(dep)!);
    }
    result.push(record);
  }
  for (const record of sortedRecords) {
    addRecord(record);
  }
  return result;
}

function collectDirectDeps(
  type: ResolvedType,
  modulePath: string,
  recordMap: ReadonlyMap<RecordKey, RecordLocation>,
  deps: Set<RecordKey>,
): void {
  switch (type.kind) {
    case "optional":
      collectDirectDeps(type.other, modulePath, recordMap, deps);
      break;
    case "record": {
      const record = recordMap.get(type.key)!;
      if (record.modulePath === modulePath) {
        deps.add(type.key);
      }
      break;
    }
  }
}
