import {
  RecordDefinition,
  TypeDefinition,
  TypeSignature,
} from "skir-codemirror-plugin";
import { Record, RecordKey, ResolvedType } from "skir-internal";
import { ModuleSet } from "skir/dist/module_set";

export function recordToTypeDefinition(
  record: Record,
  modules: ModuleSet,
): TypeDefinition {
  return new RecordToTypeDefinitionFlow(modules).run(record);
}

class RecordToTypeDefinitionFlow {
  constructor(private modules: ModuleSet) {}

  run(record: Record): TypeDefinition {
    const typeSignature = this.getRecordSignature(record.key);
    return {
      type: typeSignature,
      records: this.recordDefinitions,
    };
  }

  private getRecordSignature(recordKey: RecordKey): TypeSignature {
    const { modulePath, record, recordAncestors } =
      this.modules.recordMap.get(recordKey)!;
    const qualifiedName = recordAncestors.map((a) => a.name.text).join(".");
    const recordId = `${modulePath}:${qualifiedName}`;
    if (!this.seenRecords.has(record.key)) {
      this.seenRecords.add(record.key);
      this.addRecordDefinition(recordId, record);
    }
    return {
      kind: "record",
      value: recordId,
    };
  }

  private getTypeSignature(type: ResolvedType): TypeSignature {
    switch (type.kind) {
      case "record": {
        return this.getRecordSignature(type.key);
      }
      case "array": {
        return {
          kind: "array",
          value: {
            item: this.getTypeSignature(type.item),
            key_extractor: type.key
              ? type.key.path.map((p) => p.name.text).join(".")
              : undefined,
          },
        };
      }
      case "optional": {
        return {
          kind: "optional",
          value: this.getTypeSignature(type.other),
        };
      }
      case "primitive": {
        return {
          kind: "primitive",
          value: type.primitive,
        };
      }
    }
  }

  private addRecordDefinition(recordId: string, record: Record): void {
    let recordDefinition: RecordDefinition;
    if (record.recordType === "struct") {
      recordDefinition = {
        kind: "struct",
        id: recordId,
        doc: record.doc.text,
        fields: record.fields.map((field) => ({
          name: field.name.text,
          type: this.getTypeSignature(field.type!),
          number: field.number,
          doc: field.doc.text,
        })),
        removed_numbers: record.removedNumbers,
      };
    } else {
      recordDefinition = {
        kind: "enum",
        id: recordId,
        doc: record.doc.text,
        variants: record.fields.map((variant) => ({
          name: variant.name.text,
          type: variant.type ? this.getTypeSignature(variant.type) : undefined,
          number: variant.number,
          doc: variant.doc.text,
        })),
        removed_numbers: record.removedNumbers,
      };
    }
    this.recordDefinitions.push(recordDefinition);
  }

  private readonly seenRecords = new Set<RecordKey>();
  private readonly recordDefinitions: RecordDefinition[] = [];
}
