import { primitiveSerializer } from "skir-client";
import { toJson } from "./to_json";
import type {
  EnumDefinition,
  FieldDefinition,
  Hint,
  JsonError,
  JsonObject,
  JsonValue,
  MutableTypeHint,
  Path,
  PrimitiveType,
  RecordDefinition,
  TypeDefinition,
  TypeHint,
  TypeSignature,
  ValidationResult,
  VariantDefinition,
} from "./types";

export function validateSchema(
  value: JsonValue,
  schema: TypeDefinition,
): ValidationResult {
  const idToRecordDef: { [id: string]: RecordDefinition } = {};
  for (const record of schema.records) {
    idToRecordDef[record.id] = record;
  }

  const validator = new SchemaValidator(idToRecordDef);
  const root: Path = { kind: "root" };
  validator.validate(value, root, schema.type);
  const pathToTypeHint = new Map<Path, TypeHint>();
  for (const hint of validator.hints) {
    const { valueContext } = hint;
    if (valueContext) {
      pathToTypeHint.set(valueContext.path, hint);
    }
  }
  return {
    errors: validator.errors,
    hints: validator.hints,
    rootTypeHint: validator.rootTypeHint,
    pathToTypeHint: pathToTypeHint,
  };
}

class SchemaValidator {
  constructor(readonly idToRecordDef: { [id: string]: RecordDefinition }) {}
  readonly errors: JsonError[] = [];
  readonly hints: Hint[] = [];
  private readonly typeHintStack: MutableTypeHint[] = [];
  rootTypeHint: TypeHint | undefined;

  validate(
    value: JsonValue,
    path: Path,
    schema: TypeSignature,
    optionalSchema?: TypeSignature,
  ): void {
    const { idToRecordDef, typeHintStack } = this;
    value.expectedType = schema;
    // For every call to pushTypeHint() there emust be one call to typeHintStack.pop()
    const pushTypeHint = (options?: {
      enumDefinition?: EnumDefinition;
    }): void => {
      const typeDesc = getTypeDesc(optionalSchema ?? schema);
      const typeDoc = getTypeDoc(schema, idToRecordDef);
      const message = [typeDesc];
      if (typeDoc) {
        message.push(typeDoc);
      }
      if (value.kind === "array") {
        const { length } = value.values;
        if (length) {
          message.push(`Length: ${length}`);
        }
      }
      const hint: MutableTypeHint = {
        segment: value.firstToken,
        message: message.length === 1 ? message[0] : message,
        valueContext: { value, path },
        childHints: [],
        enumDefinition: options?.enumDefinition,
      };
      if (typeHintStack.length) {
        const topOfStack = typeHintStack[typeHintStack.length - 1];
        topOfStack.childHints.push(hint);
      } else {
        this.rootTypeHint = hint;
      }
      this.hints.push(hint);
      typeHintStack.push(hint);
    };
    switch (schema.kind) {
      case "array": {
        if (value.kind === "array") {
          pushTypeHint();
          for (const [index, item] of value.values.entries()) {
            const { key_extractor: keyExtractor, item: itemSchema } =
              schema.value;
            const itemKey = extractItemKey(item, keyExtractor);
            const itemPath: Path = {
              kind: "array-item",
              index: index,
              key: itemKey,
              arrayPath: path,
            };
            this.validate(item, itemPath, itemSchema);
          }
          typeHintStack.pop();
        } else {
          this.errors.push({
            kind: "error",
            segment: value.segment,
            message: "Expected: array",
          });
        }
        break;
      }
      case "optional": {
        if (value.kind === "literal" && value.jsonCode === "null") {
          pushTypeHint();
          typeHintStack.pop();
        } else {
          this.validate(value, path, schema.value, schema);
        }
        break;
      }
      case "primitive": {
        const primitiveType = schema.value;
        if (primitiveType === "timestamp") {
          if (this.validateTimestamp(value)) {
            pushTypeHint();
            typeHintStack.pop();
          }
        } else if (hasPrimitiveType(value, primitiveType)) {
          pushTypeHint();
          typeHintStack.pop();
        } else {
          this.errors.push({
            kind: "error",
            segment: value.firstToken,
            message: `Expected: ${primitiveType}`,
          });
        }
        break;
      }
      case "record": {
        const recordDef = idToRecordDef[schema.value];
        if (recordDef.kind === "struct") {
          const nameToFieldDef: { [name: string]: FieldDefinition } = {};
          recordDef.fields.forEach((field) => {
            nameToFieldDef[field.name] = field;
          });
          if (value.kind === "object") {
            pushTypeHint();
            for (const keyValue of Object.values(value.keyValues)) {
              const { key, value } = keyValue;
              const fieldDef = nameToFieldDef[key];
              if (fieldDef) {
                if (fieldDef.doc) {
                  this.hints.push({
                    segment: keyValue.keySegment,
                    message: fieldDef.doc,
                  });
                }
                const valuePath: Path = {
                  kind: "field-value",
                  fieldName: key,
                  structPath: path,
                };
                this.validate(value, valuePath, fieldDef.type!);
              } else {
                this.errors.push({
                  kind: "error",
                  segment: keyValue.keySegment,
                  message: "Unknown field",
                });
              }
            }
            typeHintStack.pop();
          } else {
            this.errors.push({
              kind: "error",
              segment: value.firstToken,
              message: "Expected: object",
            });
          }
        } else {
          // Enum
          const nameToVariantDef: { [name: string]: VariantDefinition } = {};
          recordDef.variants.forEach((variant) => {
            nameToVariantDef[variant.name.toLowerCase()] = variant;
            nameToVariantDef[variant.name.toUpperCase()] = variant;
          });
          if (value.kind === "object") {
            pushTypeHint();
            this.validateEnumObject(value, path, nameToVariantDef);
            typeHintStack.pop();
          } else if (value.kind === "literal" && value.type === "string") {
            const name = JSON.parse(value.jsonCode);
            const fieldDef = nameToVariantDef[name];
            if (fieldDef && fieldDef.type) {
              this.errors.push({
                kind: "error",
                segment: value.segment,
                message: "Expected: constant variant",
              });
            } else if (name === "unknown" || name === "UNKNOWN" || fieldDef) {
              pushTypeHint({ enumDefinition: recordDef });
              typeHintStack.pop();
            } else {
              this.errors.push({
                kind: "error",
                segment: value.segment,
                message: "Unknown variant",
              });
            }
          } else {
            this.errors.push({
              kind: "error",
              segment: value.firstToken,
              message: "Expected: object or string",
            });
          }
        }
        break;
      }
      default: {
        const _: never = schema;
        throw new Error(_);
      }
    }
  }

  validateEnumObject(
    object: JsonObject,
    enumPath: Path,
    nameToVariantDef: { [name: string]: VariantDefinition },
  ): void {
    const kindKv = object.keyValues["kind"];
    if (!kindKv) {
      this.errors.push({
        kind: "error",
        segment: object.segment,
        message: "Missing: 'kind'",
      });
      return;
    }
    if (kindKv.value.kind !== "literal" || kindKv.value.type !== "string") {
      this.errors.push({
        kind: "error",
        segment: kindKv.value.firstToken,
        message: "Expected: string",
      });
      return;
    }
    const kind: string = JSON.parse(kindKv.value.jsonCode);
    const variantDef = nameToVariantDef[kind];
    if (!variantDef) {
      this.errors.push({
        kind: "error",
        segment: kindKv.value.segment,
        message: "Unknown variant",
      });
      return;
    } else if (variantDef.type === undefined) {
      this.errors.push({
        kind: "error",
        segment: kindKv.value.segment,
        message: "Expected: wrapper variant",
      });
    }
    const valueKv = object.keyValues["value"];
    if (!valueKv) {
      this.errors.push({
        kind: "error",
        segment: object.segment,
        message: "Missing: 'value'",
      });
      return;
    }
    for (const key of object.allKeys) {
      if (key.key !== "kind" && key.key !== "value") {
        this.errors.push({
          kind: "error",
          segment: key.keySegment,
          message: "Unexpected entry",
        });
      }
    }
    const path: Path = {
      kind: "variant-value",
      variantName: variantDef.name,
      enumPath: enumPath,
    };
    this.validate(valueKv.value, path, variantDef.type!);
  }

  private validateTimestamp(value: JsonValue): boolean {
    if (value.kind !== "object") {
      this.errors.push({
        kind: "error",
        segment: value.firstToken,
        message: "Expected: timestamp",
      });
      return false;
    }
    const unixMillisKv = value.keyValues["unix_millis"];
    if (!unixMillisKv) {
      this.errors.push({
        kind: "error",
        segment: value.firstToken,
        message: "Missing: 'unix_millis'",
      });
      return true;
    }
    if (
      unixMillisKv.value.kind !== "literal" ||
      unixMillisKv.value.type !== "number"
    ) {
      this.errors.push({
        kind: "error",
        segment: unixMillisKv.value.firstToken,
        message: "Expected: number",
      });
      return true;
    }
    const unixMillis = toJson(unixMillisKv.value) as number;
    if (unixMillis < -8640000000000000 || 8640000000000000 < unixMillis) {
      this.errors.push({
        kind: "error",
        segment: unixMillisKv.value.firstToken,
        message: "Timestamp out of range",
      });
      return true;
    }
    // At this point: the timestamp is technically valid.
    const formatted = value.keyValues["formatted"];
    if (!formatted) {
      return true;
    }
    if (
      formatted.value.kind !== "literal" ||
      formatted.value.type !== "string"
    ) {
      this.errors.push({
        kind: "error",
        segment: formatted.value.firstToken,
        message: "Expected: string",
      });
      return true;
    }
    const formattedStr = toJson(formatted.value) as string;
    if (formattedStr === "n/a") {
      return true;
    }
    const parsedMillis = Date.parse(formattedStr);
    if (Number.isNaN(parsedMillis)) {
      this.errors.push({
        kind: "error",
        segment: formatted.value.firstToken,
        message: "Invalid ISO 8601 date string",
      });
      return true;
    }
    if (parsedMillis !== unixMillis) {
      this.errors.push({
        kind: "error",
        segment: formatted.value.firstToken,
        message: "Does not match 'unix_millis'",
      });
    }
    for (const key of value.allKeys) {
      if (key.key !== "unix_millis" && key.key !== "formatted") {
        this.errors.push({
          kind: "error",
          segment: key.keySegment,
          message: "Unexpected entry",
        });
      }
    }
    return true;
  }
}

function extractItemKey(
  item: JsonValue,
  keyExtractor: string | undefined,
): string | null {
  if (keyExtractor === undefined) {
    return null;
  }
  const pieces = keyExtractor.split(".");
  let value = item;
  for (const piece of pieces) {
    if (value.kind !== "object") {
      // Error
      return null;
    }
    const kv = value.keyValues[piece];
    if (!kv) {
      // Error
      return null;
    }
    value = kv.value;
  }
  switch (value.kind) {
    case "literal": {
      switch (value.type) {
        case "string":
        case "number":
        case "boolean":
          return value.jsonCode;
      }
      // Error
      return null;
    }
    case "object": {
      const kv = value.keyValues["unix_millis"];
      if (kv && kv.value.kind === "literal" && kv.value.type === "number") {
        return kv.value.jsonCode;
      } else {
        // Error
        return null;
      }
    }
    case "array": {
      // Error
      return null;
    }
  }
}

function hasPrimitiveType(
  value: JsonValue,
  expectedType: PrimitiveType,
): boolean {
  switch (expectedType) {
    case "bool":
      return value.kind === "literal" && value.type === "boolean";
    case "int32": {
      return isInteger(value, -2147483648n, 2147483647n);
    }
    case "int64": {
      return isInteger(value, -9223372036854775808n, 9223372036854775807n);
    }
    case "hash64": {
      return isInteger(value, 0n, 18446744073709551615n);
    }
    case "float32":
    case "float64": {
      return isFloat(value);
    }
    case "string": {
      return value.kind === "literal" && value.type === "string";
    }
    case "bytes": {
      if (value.kind !== "literal") {
        return false;
      }
      try {
        primitiveSerializer("bytes").fromJsonCode(value.jsonCode);
        return true;
      } catch {
        return false;
      }
    }
    case "timestamp": {
      // Case handled separately in validate()
      throw new Error();
    }
  }
}

function isInteger(value: JsonValue, min: bigint, max: bigint): boolean {
  if (value.kind !== "literal") {
    return false;
  }
  let decimalRep: string;
  if (value.type === "string") {
    decimalRep = JSON.parse(value.jsonCode);
  } else if (value.type === "number") {
    decimalRep = value.jsonCode;
  } else {
    return false;
  }
  let int: bigint;
  try {
    int = BigInt(decimalRep);
  } catch {
    return false;
  }
  return min <= int && int <= max;
}

function isFloat(value: JsonValue): boolean {
  if (value.kind !== "literal") {
    return false;
  }
  if (value.type === "number") {
    return true;
  } else if (
    value.type === "string" &&
    (value.jsonCode === '"NaN"' ||
      value.jsonCode === '"Infinity"' ||
      value.jsonCode === '"-Infinity"')
  ) {
    return true;
  } else {
    return false;
  }
}

function getTypeDesc(type: TypeSignature): string {
  function getTypePart(type: TypeSignature): string {
    switch (type.kind) {
      case "primitive":
        return type.value;
      case "array":
        return `[${getTypePart(type.value.item)}]`;
      case "optional":
        return `${getTypePart(type.value)}?`;
      case "record": {
        const recordId = type.value;
        return recordId.split(":")[1];
      }
    }
  }
  function getModulePart(type: TypeSignature): string | null {
    switch (type.kind) {
      case "primitive":
        return null;
      case "array":
        return getModulePart(type.value.item);
      case "optional":
        return getModulePart(type.value);
      case "record": {
        const recordId = type.value;
        return recordId.split(":")[0];
      }
    }
  }
  const typePart = getTypePart(type);
  const modulePart = getModulePart(type);
  return modulePart ? `${typePart} (${modulePart})` : typePart;
}

function getTypeDoc(
  type: TypeSignature,
  idToRecordDef: Readonly<{ [id: string]: RecordDefinition }>,
): string | undefined {
  switch (type.kind) {
    case "primitive":
      return undefined;
    case "array":
      return getTypeDoc(type.value.item, idToRecordDef);
    case "optional":
      return getTypeDoc(type.value, idToRecordDef);
    case "record": {
      const recordId = type.value;
      const recordDef = idToRecordDef[recordId]!;
      return recordDef.doc;
    }
  }
}
