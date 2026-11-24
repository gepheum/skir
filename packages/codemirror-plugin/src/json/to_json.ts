import type { Json, JsonValue, RecordDefinition, TypeSignature } from "./types";

export function toJson(value: JsonValue): Json {
  switch (value.kind) {
    case "literal": {
      return JSON.parse(value.jsonCode);
    }
    case "array": {
      return value.values.map(toJson);
    }
    case "object": {
      return Object.fromEntries(
        Object.values(value.keyValues).map((keyValue) => [
          keyValue.key,
          toJson(keyValue.value),
        ]),
      );
    }
  }
}

export function makeJsonTemplate(
  type: TypeSignature,
  idToRecordDef: { [id: string]: RecordDefinition },
  nested?: "nested",
): Json {
  switch (type.kind) {
    case "array": {
      return [];
    }
    case "optional": {
      return null;
    }
    case "record": {
      const recordDef = idToRecordDef[type.value]!;
      if (recordDef.kind === "struct") {
        if (nested) {
          return {};
        }
        return Object.fromEntries(
          recordDef.fields.map((field) => [
            field.name,
            makeJsonTemplate(field.type!, idToRecordDef, "nested"),
          ]),
        );
      } else {
        // Enum
        return "UNKNOWN";
      }
    }
    case "primitive": {
      switch (type.value) {
        case "bool":
          return false;
        case "int32":
        case "float32":
        case "float64":
          return 0;
        case "int64":
        case "hash64":
          return "0";
        case "timestamp":
          return { unix_millis: 0, formatted: "1970-01-01T00:00:00Z" };
        case "string":
        case "bytes":
          return "";
      }
    }
  }
}
