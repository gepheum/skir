import type {
  EnumDefinition,
  Method,
  MethodList,
  PrimitiveType,
  RecordDefinition,
  StructDefinition,
  TypeDefinition,
  TypeSignature,
} from "skir-codemirror-plugin";

export type { Method, MethodList };

/**
 * Generates the contents of an `llms.txt` file that explains to an AI how to
 * call a Skir service: available methods, request/response JSON Schemas, and
 * curl examples.
 *
 * @param methodList - The service method list (as returned by the `?list`
 *   endpoint).
 * @param serviceUrl - The base URL of the service, e.g.
 *   `"http://localhost:8787/geometry"`.
 */
export function generateLlmsTxt(
  methodList: MethodList,
  serviceUrl: string,
  auth: "auth" | "no-auth" = "no-auth",
): string {
  const lines: string[] = [];

  lines.push("# API Documentation");
  lines.push("");
  lines.push(`Base URL: ${serviceUrl}`);
  lines.push("");
  lines.push("## How to call this service");
  lines.push("");
  lines.push(
    "Send an HTTP POST request to the base URL with a JSON body containing:",
  );
  lines.push("- `method`: the method name (string)");
  lines.push("- `request`: the request payload (see schema for each method)");
  lines.push("");
  lines.push("The response body is the JSON-serialized response value.");
  lines.push("");

  if (auth === "auth") {
    lines.push(
      "> **IMPORTANT — keep `MY_API_BEARER_TOKEN` secret.** " +
        "Never echo, log, print, or expose the value of `MY_API_BEARER_TOKEN` " +
        "in any output, response, code snippet, or tool call. " +
        "Treat it as a credential that must never leave the local environment.",
    );
    lines.push("");
  }

  lines.push("## Methods");
  lines.push("");

  for (const method of methodList.methods) {
    lines.push(`### ${method.method}`);
    lines.push("");

    if (method.doc) {
      lines.push(method.doc);
      lines.push("");
    }

    lines.push("**Request (curl):**");
    lines.push("");
    lines.push("```bash");
    lines.push("curl -X POST \\");
    lines.push('  -H "Content-Type: application/json" \\');
    if (auth === "auth") {
      lines.push('  -H "Authorization: Bearer ${MY_API_BEARER_TOKEN}" \\');
    }
    lines.push(
      `  -d '{"method": "${method.method}", "request": <request_json>}' \\`,
    );
    lines.push(`  ${serviceUrl}`);
    lines.push("```");
    lines.push("");

    lines.push(
      `**Request schema:** see \`$defs["${method.method}:request"]\` in the shared schema below`,
    );
    lines.push("");
    lines.push(
      `**Response schema:** see \`$defs["${method.method}:response"]\` in the shared schema below`,
    );
    lines.push("");

    lines.push("---");
    lines.push("");
  }

  lines.push("## Shared JSON schema");
  lines.push("");
  lines.push(
    "All types referenced above are defined in the following shared schema.",
  );
  lines.push("");
  lines.push("```json");
  lines.push(JSON.stringify(buildSharedSchema(methodList), null, 2));
  lines.push("```");
  lines.push("");

  return lines.join("\n");
}

// -----------------------------------------------------------------------------
// JSON Schema generation
// -----------------------------------------------------------------------------

type JsonSchema = Record<string, unknown>;

// Well-known $defs keys for the complex primitive types.
const PRIMITIVE_DEF_KEYS: Partial<Record<PrimitiveType, string>> = {
  int64: "$primitive:int64",
  hash64: "$primitive:hash64",
  float32: "$primitive:float32",
  float64: "$primitive:float64",
  timestamp: "$primitive:timestamp",
  bytes: "$primitive:bytes",
};

const PRIMITIVE_DEFS: Record<string, JsonSchema> = {
  "$primitive:int64": {
    oneOf: [
      { type: "integer" },
      { type: "string", pattern: "^-?(?:0|[1-9][0-9]*)$" },
    ],
    description:
      "64-bit signed integer; serialized as a string when outside the JS safe integer range (±9,007,199,254,740,991)",
  },
  "$primitive:hash64": {
    oneOf: [
      { type: "integer" },
      { type: "string", pattern: "^(?:0|[1-9][0-9]*)$" },
    ],
    description:
      "64-bit unsigned hash; serialized as a string when outside the JS safe integer range",
  },
  "$primitive:float32": {
    oneOf: [
      { type: "number" },
      { type: "string", enum: ["NaN", "Infinity", "-Infinity"] },
    ],
    description: "32-bit floating-point number",
  },
  "$primitive:float64": {
    oneOf: [
      { type: "number" },
      { type: "string", enum: ["NaN", "Infinity", "-Infinity"] },
    ],
    description: "64-bit floating-point number",
  },
  "$primitive:timestamp": {
    type: "object",
    properties: {
      unix_millis: {
        type: "integer",
        minimum: Number.MIN_SAFE_INTEGER,
        maximum: Number.MAX_SAFE_INTEGER,
        description: "Milliseconds since the Unix epoch",
      },
    },
    description: "Point in time",
  },
  "$primitive:bytes": {
    type: "string",
    pattern: "^hex:([0-9a-fA-F]{2})*$",
    description:
      'Byte sequence encoded as a hex string prefixed with "hex:", e.g. "hex:48656c6c6f"',
  },
};

/**
 * Builds a single shared JSON Schema document whose `$defs` contains:
 * - All complex primitive types (int64, hash64, float32, float64, timestamp)
 * - All record types (structs and enums) referenced across all methods
 * - Per-method request/response root schemas keyed as
 *   `"<MethodName>:request"` and `"<MethodName>:response"`
 */
function buildSharedSchema(methodList: MethodList): JsonSchema {
  // Deduplicated map of all record definitions across all methods.
  const recordMap = new Map<string, RecordDefinition>();

  function collectRecords(typeDef: TypeDefinition): void {
    for (const record of typeDef.records) {
      if (!recordMap.has(record.id)) {
        recordMap.set(record.id, record);
      }
    }
  }

  for (const method of methodList.methods) {
    collectRecords(method.request);
    collectRecords(method.response);
  }

  const defs: Record<string, JsonSchema> = {};

  // Tracks records currently being expanded to break recursive cycles.
  const inProgress = new Set<string>();

  function ensureRecord(id: string): void {
    if (id in defs || inProgress.has(id)) return;
    inProgress.add(id);
    const record = recordMap.get(id);
    if (record) {
      defs[id] = buildRecordSchema(record);
    }
    inProgress.delete(id);
  }

  function typeSignatureToSchema(type: TypeSignature): JsonSchema {
    switch (type.kind) {
      case "primitive": {
        const defKey = PRIMITIVE_DEF_KEYS[type.value];
        if (defKey) {
          if (!(defKey in defs)) {
            defs[defKey] = PRIMITIVE_DEFS[defKey];
          }
          return { $ref: `#/$defs/${defKey}` };
        }
        return primitiveToInlineSchema(type.value);
      }

      case "optional": {
        const inner = typeSignatureToSchema(type.value);
        return { oneOf: [{ type: "null" }, inner] };
      }

      case "array": {
        const schema: JsonSchema = {
          type: "array",
          items: typeSignatureToSchema(type.value.item),
        };
        if (type.value.key_extractor) {
          schema.description = `Keyed array; items are uniquely identified by the '${type.value.key_extractor}' field`;
        }
        return schema;
      }

      case "record": {
        ensureRecord(type.value);
        return { $ref: `#/$defs/${type.value}` };
      }
    }
  }

  function buildRecordSchema(record: RecordDefinition): JsonSchema {
    return record.kind === "struct"
      ? buildStructSchema(record)
      : buildEnumSchema(record);
  }

  function buildStructSchema(struct: StructDefinition): JsonSchema {
    const properties: Record<string, JsonSchema> = {};

    for (const field of struct.fields) {
      const fieldSchema: JsonSchema = { ...typeSignatureToSchema(field.type) };
      if (field.doc) {
        fieldSchema.description = field.doc;
      }
      properties[field.name] = fieldSchema;
    }

    const schema: JsonSchema = { type: "object", properties };
    if (struct.doc) schema.description = struct.doc;
    return schema;
  }

  function buildEnumSchema(enumDef: EnumDefinition): JsonSchema {
    const constVariants = enumDef.variants.filter((v) => !v.type);
    const wrapperVariants = enumDef.variants.filter((v) => v.type);

    const options: JsonSchema[] = [];

    const constNames = [...constVariants.map((v) => v.name), "UNKNOWN"];
    const constSchema: JsonSchema = { type: "string", enum: constNames };
    const constDocs = constVariants
      .filter((v) => v.doc)
      .map((v) => `${v.name}: ${v.doc}`);
    if (constDocs.length > 0) {
      constSchema.description = constDocs.join("; ");
    }
    options.push(constSchema);

    for (const variant of wrapperVariants) {
      const obj: JsonSchema = {
        type: "object",
        properties: {
          kind: { type: "string", enum: [variant.name] },
          value: typeSignatureToSchema(variant.type!),
        },
        required: ["kind", "value"],
      };
      if (variant.doc) obj.description = variant.doc;
      options.push(obj);
    }

    const schema: JsonSchema =
      options.length === 1 ? { ...options[0] } : { oneOf: options };
    if (enumDef.doc) schema.description = enumDef.doc;
    return schema;
  }

  // Build per-method root schemas and add them to $defs.
  for (const method of methodList.methods) {
    defs[`${method.method}:request`] = typeSignatureToSchema(
      method.request.type,
    );
    defs[`${method.method}:response`] = typeSignatureToSchema(
      method.response.type,
    );
  }

  return { $defs: defs };
}

/** Inline schema for primitives that don't get their own $defs entry. */
function primitiveToInlineSchema(primitive: PrimitiveType): JsonSchema {
  switch (primitive) {
    case "bool":
      return { type: "boolean" };
    case "int32":
      return { type: "integer" };
    case "string":
      return { type: "string" };
    default:
      // Should never be reached – complex primitives are handled via $ref.
      return {};
  }
}
