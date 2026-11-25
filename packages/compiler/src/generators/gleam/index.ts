import {
  type CodeGenerator,
  type Constant,
  type Doc,
  type Method,
  type RecordKey,
  type RecordLocation,
  type ResolvedType,
  type Value,
  convertCase,
  unquoteAndUnescape,
} from "skir-internal";
import { z } from "zod";
import { getModuleDir, getTypeName, toFieldName } from "./naming.js";
import { TypeSpeller } from "./type_speller.js";

const Config = z.strictObject({
  // If skirout is at the root of the src directory, this should be "skirout".
  // Otherwise, this should be the relative path from the src directory to the
  // skirout directory.
  importPathToSkirout: z
    .string()
    .regex(/^(?:[a-z][a-z0-9_]*\/)*skirout$/)
    .optional(),
});

type Config = z.infer<typeof Config>;

/**
 * Information about the Gleam source file generated for one Skir module.
 */
interface GroupInfo {
  /** Records in this group (sorted in original declaration order). */
  records: readonly RecordLocation[];
  /** Constants declared at the top-level of the corresponding Skir module. */
  constants: readonly Constant<false>[];
  /** Methods declared at the top-level of the corresponding Skir module. */
  methods: readonly Method<false>[];
  /** Output file path relative to outDir, e.g. "gepheum/foo/bar__baz.gleam". */
  outputPath: string;
  /** Gleam import path, e.g. "skirout/gepheum/foo/bar__baz". */
  importPath: string;
  /** Gleam import alias, e.g. "gepheum__foo__bar__baz". */
  alias: string;
  /** Set of all record keys contained in this group (for fast lookup). */
  keySet: ReadonlySet<RecordKey>;
}

class GleamCodeGenerator implements CodeGenerator<Config> {
  readonly id = "skir-gleam-gen";
  readonly configType = Config;

  generateCode(input: CodeGenerator.Input<Config>): CodeGenerator.Output {
    const { config, recordMap } = input;
    const outputFiles: CodeGenerator.OutputFile[] = [];

    // First pass: compute groups and name maps for every module.
    const keyToGroup = new Map<RecordKey, GroupInfo>();
    const pathToGroup = new Map<string, GroupInfo>(); // .skir module path → GroupInfo
    const uniqueTypeNames = new Map<RecordKey, string>();
    const allCtorNames = new Map<string, string>();
    for (const module of input.modules) {
      const group = computeGroupForModule(
        module.records,
        module.constants as readonly Constant<false>[],
        module.methods as readonly Method<false>[],
        config,
        module.path,
      );
      if (group) {
        pathToGroup.set(module.path, group);
        for (const key of group.keySet) {
          keyToGroup.set(key, group);
        }
      }
      const { typeNames, ctorNames } = computeModuleNames(module.records);
      for (const [k, v] of typeNames) uniqueTypeNames.set(k, v);
      for (const [k, v] of ctorNames) allCtorNames.set(k, v);
    }

    // Second pass: generate code for each group.
    for (const module of input.modules) {
      const group = pathToGroup.get(module.path);
      if (group === undefined) continue;
      outputFiles.push({
        path: group.outputPath,
        code: new GleamSourceFileGenerator(
          group,
          recordMap,
          keyToGroup,
          uniqueTypeNames,
          allCtorNames,
          Object.keys(module.pathToImportedNames),
          pathToGroup,
        ).generate(),
      });
    }

    return { files: outputFiles };
  }
}

/**
 * Returns a single GroupInfo containing all symbols from the given Skir module,
 * or undefined if the module has no symbols.
 * All types from one .skir file are co-located in one Gleam module.
 */
function computeGroupForModule(
  records: readonly RecordLocation[],
  constants: readonly Constant<false>[] = [],
  methods: readonly Method<false>[] = [],
  config: Config,
  modulePath?: string,
): GroupInfo | undefined {
  if (records.length === 0 && constants.length === 0 && methods.length === 0)
    return undefined;
  let moduleDir: string;
  if (records.length > 0) {
    moduleDir = getModuleDir(records[0]!.modulePath);
  } else if (modulePath) {
    moduleDir = getModuleDir(modulePath);
  } else {
    return undefined;
  }
  return {
    records: [...records],
    constants: [...constants],
    methods: [...methods],
    outputPath: `${moduleDir}.gleam`,
    importPath: `${config.importPathToSkirout ?? "skirout"}/${moduleDir}`,
    alias: moduleDir.replace(/\//g, "__") + "_",
    keySet: new Set(records.map((r) => r.record.key)),
  };
}

/**
 * Computes unique Gleam names for all types and variant constructors in a
 * single Skir module using BFS depth-order processing with "X" collision
 * avoidance. Both type names and constructor names share the same collision
 * namespace to avoid any ambiguity.
 *
 * Returns:
 * - typeNames: RecordKey → Gleam type name (UpperCamel)
 * - ctorNames: "${recordKey}:${variantText}" → Gleam constructor name
 *   (use "__unknown__" as the variant text for the implicit Unknown constructor)
 */
function computeModuleNames(records: readonly RecordLocation[]): {
  typeNames: Map<RecordKey, string>;
  ctorNames: Map<string, string>;
} {
  const taken = new Set<string>();
  const typeNames = new Map<RecordKey, string>();
  const ctorNames = new Map<string, string>();

  if (records.length === 0) return { typeNames, ctorNames };

  // Build a lookup from ancestor-path string → record key.
  const pathToKey = new Map<string, RecordKey>();
  for (const rec of records) {
    const path = rec.recordAncestors.map((a) => a.name.text).join("\0");
    pathToKey.set(path, rec.record.key);
  }

  const parentKeyOf = (rec: RecordLocation): RecordKey | undefined => {
    if (rec.recordAncestors.length <= 1) return undefined;
    const parentPath = rec.recordAncestors
      .slice(0, -1)
      .map((a) => a.name.text)
      .join("\0");
    return pathToKey.get(parentPath);
  };

  // Group records by depth (0 = top-level).
  const byDepth: RecordLocation[][] = [];
  for (const rec of records) {
    const depth = rec.recordAncestors.length - 1;
    while (byDepth.length <= depth) byDepth.push([]);
    byDepth[depth]!.push(rec);
  }

  // Assign a unique name, appending "X" until there is no collision.
  const assign = (candidate: string): string => {
    while (taken.has(candidate)) candidate += "X";
    taken.add(candidate);
    return candidate;
  };

  // Process each depth level. At depth N we assign:
  //   - type names for depth-N records
  //   - constructor names for variants of depth-(N-1) enums
  // We run one extra iteration (depth == byDepth.length) to process
  // variant constructors of the deepest enums.
  for (let depth = 0; depth <= byDepth.length; depth++) {
    // Assign type names for records at this depth.
    for (const rec of byDepth[depth] ?? []) {
      const ownName = convertCase(
        rec.recordAncestors.at(-1)!.name.text,
        "UpperCamel",
      );
      const pk = parentKeyOf(rec);
      const parentName = pk !== undefined ? (typeNames.get(pk) ?? "") : "";
      typeNames.set(rec.record.key, assign(parentName + ownName));
    }

    // Assign constructor names for variants of depth-(depth-1) enums.
    if (depth > 0) {
      for (const rec of byDepth[depth - 1] ?? []) {
        if (rec.record.recordType !== "enum") continue;
        const typeName = typeNames.get(rec.record.key)!;
        // Implicit Unknown constructor.
        ctorNames.set(
          `${rec.record.key}:__unknown__`,
          assign(typeName + "Unknown"),
        );
        // User-defined variant constructors.
        for (const variant of rec.record.fields) {
          const variantPart = convertCase(variant.name.text, "UpperCamel");
          ctorNames.set(
            `${rec.record.key}:${variant.name.text}`,
            assign(typeName + variantPart),
          );
        }
      }
    }
  }

  return { typeNames, ctorNames };
}

// Generates the code for one Gleam source file (one GroupInfo → one file).
/** Ordered list of client library module paths and their import aliases. */
const CLIENT_MODULES: ReadonlyArray<readonly [string, string]> = [
  ["gleam/option", "option_"],
  ["gleam/dynamic/decode", "decode_"],
  ["skir_client/timestamp", "timestamp_"],
  ["skir_client/recursive", "recursive_"],
  ["skir_client/method", "method_"],
  ["skir_client", "skir_client_"],
  ["skir_client/type_descriptor", "type_descriptor_"],
  ["skir_client/internal/struct_serializer", "struct_serializer_"],
  ["gleam/list", "list_"],
  ["gleam/result", "result_"],
  ["skir_client/internal/enum_serializer", "enum_serializer_"],
] as const;

class GleamSourceFileGenerator {
  private code = "";
  private readonly neededModules = new Set<string>();
  private readonly typeSpeller: TypeSpeller;

  constructor(
    private readonly group: GroupInfo,
    private readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>,
    private readonly keyToGroup: ReadonlyMap<RecordKey, GroupInfo>,
    private readonly uniqueTypeNames: ReadonlyMap<RecordKey, string>,
    private readonly ctorNames: ReadonlyMap<string, string>,
    private readonly importedModulePaths: readonly string[],
    private readonly pathToGroup: ReadonlyMap<string, GroupInfo>,
  ) {
    // Returns the unique Gleam type name for a given record key.
    const uniqueNameFor = (key: RecordKey): string => {
      return uniqueTypeNames.get(key) ?? getTypeName(recordMap.get(key)!);
    };

    // Compute the function name for a given record key and base name.
    // The prefix is the full ancestor path in lower_underscore joined by "__".
    const fnNameFor = (key: RecordKey, base: string): string => {
      const rec = recordMap.get(key)!;
      const prefix = rec.recordAncestors
        .map((a) => convertCase(a.name.text, "lower_underscore"))
        .join("__");
      return `${prefix}_${base}`;
    };

    const typeExprFor = (key: RecordKey): string => {
      const typeName = uniqueNameFor(key);
      if (group.keySet.has(key)) return typeName;
      return `${keyToGroup.get(key)!.alias}.${typeName}`;
    };

    const defaultExprFor = (key: RecordKey): string => {
      const rec = recordMap.get(key)!;
      const baseName = rec.record.recordType === "enum" ? "unknown" : "default";
      const name = fnNameFor(key, baseName);
      if (group.keySet.has(key)) return name;
      const alias = keyToGroup.get(key)!.alias;
      return `${alias}.${name}`;
    };

    const serializerExprFor = (key: RecordKey): string => {
      const fn = fnNameFor(key, "serializer");
      if (group.keySet.has(key)) return `${fn}()`;
      return `${keyToGroup.get(key)!.alias}.${fn}()`;
    };

    this.typeSpeller = new TypeSpeller(
      recordMap,
      typeExprFor,
      defaultExprFor,
      serializerExprFor,
      this.neededModules,
    );
  }

  generate(): string {
    // http://patorjk.com/software/taag/#f=Doom&t=Do%20not%20edit
    this.push(
      `//  ______                        _               _  _  _
//  |  _  \\                      | |             | |(_)| |
//  | | | |  ___    _ __    ___  | |_    ___   __| | _ | |_
//  | | | | / _ \\  | '_ \\  / _ \\ | __|  / _ \\ / _\` || || __|
//  | |/ / | (_) | | | | || (_) || |_  |  __/| (_| || || |_
//  |___/   \\___/  |_| |_| \\___/  \\__|  \\___| \\__,_||_| \\__|
//
// Generated by skir-gleam-gen
// Home: https://skir.build/docs/gleam
//
// To install the Skir client library, run:
//   gleam add skir_client
//
// Do not edit this file manually.

`,
    );

    // Save the header (banner comment), then generate all body code into
    // this.code. Body generation populates this.neededModules.
    const header = this.code;
    this.code = "";

    for (const recordLocation of this.group.records) {
      const { record } = recordLocation;
      if (record.recordType === "struct") {
        this.writeTypesForStruct(recordLocation);
      } else {
        this.writeTypesForEnum(recordLocation);
      }
    }

    this.writeConstants();

    for (const method of this.group.methods) {
      this.writeMethod(method);
    }

    const body = this.code;

    // Build imports from the collected set, in canonical order.
    this.code = header;
    this.writeImports();
    this.push(body);

    return this.joinLinesAndFixFormatting();
  }

  private writeImports(): void {
    // Client library modules, in canonical order.
    for (const [modulePath, alias] of CLIENT_MODULES) {
      if (this.neededModules.has(modulePath)) {
        this.push(`import ${modulePath} as ${alias}\n`);
      }
    }

    // Cross-module skirout imports.
    const seenGroupAliases = new Set<string>();
    for (const importedPath of this.importedModulePaths) {
      const refGroup = this.pathToGroup.get(importedPath);
      if (!refGroup || refGroup === this.group) continue;
      if (seenGroupAliases.has(refGroup.alias)) continue;
      seenGroupAliases.add(refGroup.alias);
      this.push(`import ${refGroup.importPath} as ${refGroup.alias}\n`);
    }

    this.push("\n");
  }

  private writeConstants(): void {
    for (const constant of this.group.constants) {
      if (!constant.type || constant.valueAsDenseJson === undefined) continue;
      const gleamName =
        convertCase(constant.name.text, "lower_underscore") + "_const";
      const doc = commentify(docToCommentText(constant.doc));
      this.pushSeparator(`constant ${constant.name.text}`);
      const gleamType = this.typeSpeller.getGleamType(constant.type);
      const constExpr = this.valueToGleamExpr(constant.value, constant.type);
      if (doc) this.push(doc);
      this.push(`pub const ${gleamName}: ${gleamType} = ${constExpr}\n\n`);
    }
  }

  /**
   * Generates a Gleam const expression for a Skir value.
   */
  private valueToGleamExpr(value: Value, type: ResolvedType): string {
    switch (type.kind) {
      case "optional": {
        if (value.kind === "literal" && value.token.text === "null") {
          this.neededModules.add("gleam/option");
          return "option_.None";
        }
        const inner = this.valueToGleamExpr(value, type.other);
        this.neededModules.add("gleam/option");
        return `option_.Some(\n${inner}\n)`;
      }
      case "array": {
        if (value.kind !== "array") throw new Error("Expected array value");
        const items = value.items.map((item) =>
          this.valueToGleamExpr(item, type.item),
        );
        return `[\n${items.join(",\n")}\n]`;
      }
      case "primitive": {
        if (value.kind !== "literal") throw new Error("Expected literal value");
        return this.primitiveToGleamExpr(value.token.text, type.primitive);
      }
      case "record": {
        const recordLoc = this.recordMap.get(type.key);
        if (!recordLoc)
          throw new Error(`Record not found: ${String(type.key)}`);
        if (recordLoc.record.recordType === "struct") {
          return this.structValueToGleamExpr(value, recordLoc);
        } else {
          return this.enumValueToGleamExpr(value, recordLoc);
        }
      }
    }
  }

  private primitiveToGleamExpr(tokenText: string, primitive: string): string {
    switch (primitive) {
      case "bool":
        return tokenText === "true" ? "True" : "False";
      case "int32":
      case "int64":
      case "hash64":
        // Integer literals are valid Gleam const expressions as-is.
        return tokenText;
      case "float32":
      case "float64": {
        if (tokenText.startsWith('"') || tokenText.startsWith("'")) {
          // Special values encoded as strings: "Infinity", "-Infinity", "NaN".
          // Mirror the fallbacks used by float_decode_json in serializers.gleam.
          const special = unquoteAndUnescape(tokenText);
          switch (special) {
            case "Infinity":
              return "1.7976931348623157e308";
            case "-Infinity":
              return "-1.7976931348623157e308";
            default:
              // NaN and any other unrecognised string → 0.0
              return "0.0";
          }
        }
        // Gleam float literals require a decimal point.
        if (
          !tokenText.includes(".") &&
          !tokenText.toLowerCase().includes("e")
        ) {
          return `${tokenText}.0`;
        }
        return tokenText;
      }
      case "string": {
        // unquoteAndUnescape handles both single- and double-quoted Skir strings,
        // including line continuations. JSON.stringify gives a valid Gleam string.
        const unescaped = unquoteAndUnescape(tokenText);
        return JSON.stringify(unescaped);
      }
      case "bytes": {
        // Token is a quoted "hex:DEADBEEF..." string.
        const raw = unquoteAndUnescape(tokenText);
        const hex = raw.startsWith("hex:") ? raw.slice(4) : raw;
        if (hex.length === 0) return "<<>>";
        const bytes: number[] = [];
        for (let i = 0; i < hex.length; i += 2) {
          bytes.push(parseInt(hex.slice(i, i + 2), 16));
        }
        return `<<${bytes.join(", ")}>>`;
      }
      case "timestamp": {
        const isoString = unquoteAndUnescape(tokenText);
        const ms = new Date(isoString).getTime();
        if (Number.isNaN(ms)) {
          throw new Error(`Cannot parse timestamp: ${tokenText}`);
        }
        this.neededModules.add("skir_client/timestamp");
        return `timestamp_.Timestamp(unix_millis: ${ms})`;
      }
      default:
        throw new Error(`Unknown primitive type: ${primitive}`);
    }
  }

  private structValueToGleamExpr(value: Value, record: RecordLocation): string {
    if (value.kind !== "object") throw new Error("Expected object for struct");
    const typeName = this.typeNameFor(record);
    const prefix = this.qualifiedPrefixFor(record);
    this.neededModules.add("skir_client/internal/struct_serializer");
    // Sort fields alphabetically to match the generated type definition.
    const fields = [...record.record.fields].sort((a, b) =>
      a.name.text.localeCompare(b.name.text),
    );
    const args: string[] = [];
    for (const field of fields) {
      if (!field.type) continue;
      const fieldName = toFieldName(field.name.text);
      const entry = value.entries[field.name.text];
      if (field.isRecursive === "hard") {
        this.neededModules.add("skir_client/recursive");
        if (entry) {
          const innerExpr = this.valueToGleamExpr(entry.value, field.type);
          args.push(`${fieldName}: recursive_.Some(\n${innerExpr}\n)`);
        } else {
          args.push(`${fieldName}: recursive_.Default`);
        }
      } else {
        if (entry) {
          args.push(
            `${fieldName}: ${this.valueToGleamExpr(entry.value, field.type)}`,
          );
        } else {
          args.push(
            `${fieldName}: ${this.typeSpeller.getDefaultExpression(field.type)}`,
          );
        }
      }
    }
    args.push("unrecognized_: struct_serializer_.None");
    return `${prefix}${typeName}(\n${args.join(",\n")}\n)`;
  }

  private enumValueToGleamExpr(value: Value, record: RecordLocation): string {
    const prefix = this.qualifiedPrefixFor(record);
    if (value.kind === "literal") {
      // A string literal naming a constant (no-payload) variant.
      const valueType = value.type;
      if (!valueType || valueType.kind !== "enum") {
        // The UNKNOWN variant is not assigned a type by the compiler.
        // Reference the pre-generated "unknown" default const.
        return `${prefix}${this.fnPrefixFor(record)}unknown`;
      }
      const ctorName =
        this.ctorNames.get(
          `${record.record.key}:${valueType.variant.name.text}`,
        ) ??
        (this.uniqueTypeNames.get(record.record.key) ?? "") +
          convertCase(valueType.variant.name.text, "UpperCamel");
      return `${prefix}${ctorName}`;
    } else if (value.kind === "object") {
      // An object {kind: "variantName", value: payload} for a wrapper variant.
      const kindEntry = value.entries["kind"];
      if (!kindEntry || kindEntry.value.kind !== "literal") {
        throw new Error("Expected 'kind' entry in enum object value");
      }
      const variantName = unquoteAndUnescape(kindEntry.value.token.text);
      const ctorName =
        this.ctorNames.get(`${record.record.key}:${variantName}`) ??
        (this.uniqueTypeNames.get(record.record.key) ?? "") +
          convertCase(variantName, "UpperCamel");
      const payloadEntry = value.entries["value"];
      if (!payloadEntry) {
        throw new Error("Expected 'value' entry in enum wrapper variant");
      }
      const variantDecl = record.record.nameToDeclaration[variantName];
      if (!variantDecl || variantDecl.kind !== "field" || !variantDecl.type) {
        throw new Error(`Wrapper variant field not found: ${variantName}`);
      }
      const payloadExpr = this.valueToGleamExpr(
        payloadEntry.value,
        variantDecl.type,
      );
      return `${prefix}${ctorName}(\n${payloadExpr}\n)`;
    } else {
      throw new Error(`Unexpected value kind for enum: ${value.kind}`);
    }
  }

  private writeMethod(method: Method<false>): void {
    this.neededModules.add("skir_client/method");
    const { typeSpeller } = this;
    const gleamName =
      convertCase(method.name.text, "lower_underscore") + "_method";
    const requestType = typeSpeller.getGleamType(method.requestType!);
    const responseType = typeSpeller.getGleamType(method.responseType!);
    const requestSerializerExpr = typeSpeller.getSerializerExpression(
      method.requestType!,
    );
    const responseSerializerExpr = typeSpeller.getSerializerExpression(
      method.responseType!,
    );
    this.pushSeparator(`method ${method.name.text}`);
    const doc = commentify(docToCommentText(method.doc));
    if (doc) this.push(doc);
    this.push(
      `pub fn ${gleamName}() -> method_.Method(${requestType}, ${responseType}) {\n`,
    );
    this.push(`method_.Method(\n`);
    this.push(`name: ${JSON.stringify(method.name.text)},\n`);
    this.push(`number: ${method.number},\n`);
    this.push(`doc: ${JSON.stringify(docToCommentText(method.doc))},\n`);
    this.push(`request_serializer: ${requestSerializerExpr},\n`);
    this.push(`response_serializer: ${responseSerializerExpr},\n`);
    this.push(`)\n`);
    this.push(`}\n\n`);
  }

  private writeTypesForStruct(struct: RecordLocation): void {
    this.neededModules.add("skir_client");
    this.neededModules.add("skir_client/internal/struct_serializer");
    this.neededModules.add("gleam/list");
    this.neededModules.add("gleam/result");
    const { typeSpeller } = this;
    const typeName = this.typeNameFor(struct);
    const fnPrefix = this.fnPrefixFor(struct);
    // Sort fields by name for consistent output.
    const fields = [...struct.record.fields].sort((a, b) =>
      a.name.text.localeCompare(b.name.text),
    );

    this.pushSeparator(
      `struct ${struct.recordAncestors.map((r) => r.name.text).join(".")}`,
    );

    // Doc comment.
    this.push(commentify(docToCommentText(struct.record.doc)));

    // Type definition.
    // Hard-recursive fields are stored as recursive_.Recursive(T).
    this.push(`pub type ${typeName} {\n`);
    this.push(`${typeName}(\n`);
    for (const field of fields) {
      const fieldName = toFieldName(field.name.text);
      this.push(commentify(docToCommentText(field.doc)));
      const gleamType = typeSpeller.getFieldGleamType(field);
      this.push(`${fieldName}: ${gleamType},\n`);
    }
    // Trailing underscore avoids conflict with user-defined fields named `unrecognized`.
    this.push(
      "/// Stores unrecognized fields from newer schema versions for round-trip compatibility.\n",
      "/// Set this to `struct_serializer_.None` when creating values manually.\n",
      `unrecognized_: struct_serializer_.UnrecognizedFields(${typeName}),\n`,
    );
    this.push(")\n");
    this.push("}\n\n");

    // Default const.
    this.push(
      `/// The default \`${typeName}\` with all fields set to their default values.\n`,
    );
    this.push(`pub const ${fnPrefix}default = ${typeName}(\n`);
    for (const field of fields) {
      const fieldName = toFieldName(field.name.text);
      const defExpr = typeSpeller.getFieldDefaultExpression(field);
      this.push(`${fieldName}: ${defExpr},\n`);
    }
    this.push(`unrecognized_: struct_serializer_.None,\n`);
    this.push(")\n\n");

    // `new` constructor function.
    this.push(
      `/// Creates a new \`${typeName}\` with the given field values.\n`,
    );
    this.push(`pub fn ${fnPrefix}new(\n`);
    for (const field of fields) {
      const fieldName = toFieldName(field.name.text);
      const gleamType = typeSpeller.getFieldGleamType(field);
      this.push(`${fieldName} ${fieldName}: ${gleamType},\n`);
    }
    this.push(`) -> ${typeName} {\n`);
    this.push(`${typeName}(\n`);
    for (const field of fields) {
      const fieldName = toFieldName(field.name.text);
      this.push(`${fieldName}: ${fieldName},\n`);
    }
    this.push(`unrecognized_: struct_serializer_.None,\n`);
    this.push(`)\n`);
    this.push(`}\n\n`);

    // Serializer.
    const fieldsByNumber = [...struct.record.fields].sort(
      (a, b) => a.number - b.number,
    );

    const structDefaultExpr = `${fnPrefix}default`;
    this.push(`/// Returns the serializer for \`${typeName}\` values.\n`);
    this.push(
      `pub fn ${fnPrefix}serializer() -> skir_client_.Serializer(${typeName}) {\n`,
    );
    // Hoist non-recursive serializer construction so it is created once and
    // reused in ordered_fields, decode_dense_json, and decode_binary.
    for (const field of fieldsByNumber) {
      if (field.isRecursive === false) {
        const varName = toFieldName(field.name.text);
        const serExpr = typeSpeller.getFieldSerializerExpression(field);
        this.push(`let ${varName}_serializer = ${serExpr}\n`);
      }
    }
    this.push(`struct_serializer_.new_serializer(\n`);
    this.push(`name: ${JSON.stringify(struct.record.name.text)},\n`);
    this.push(
      `qualified_name: ${JSON.stringify(struct.recordAncestors.map((r) => r.name.text).join("."))},\n`,
    );
    this.push(`module_path: ${JSON.stringify(struct.modulePath)},\n`);
    this.push(`doc: ${JSON.stringify(docToCommentText(struct.record.doc))},\n`);
    this.push(`ordered_fields: [\n`);
    for (const field of fieldsByNumber) {
      const fieldName = toFieldName(field.name.text);
      const isRecursive = field.isRecursive !== false;
      const fieldType = typeSpeller.getFieldGleamType(field);
      this.push(`struct_serializer_.field_spec_to_field_adapter(\n`);
      this.push(`name: ${JSON.stringify(field.name.text)},\n`);
      this.push(`number: ${field.number},\n`);
      this.push(`doc: ${JSON.stringify(docToCommentText(field.doc))},\n`);
      this.push(`default: ${typeSpeller.getFieldDefaultExpression(field)},\n`);
      this.push(
        `type_sig: ${typeSpeller.getTypeSignatureExpression(field.type!)},\n`,
      );
      this.push(`get: fn(s: ${typeName}) { s.${fieldName} },\n`);
      this.push(
        `set: fn(s: ${typeName}, v: ${fieldType}) { ${typeName}(..s, ${fieldName}: v) },\n`,
      );
      if (isRecursive) {
        this.push(`serializer: struct_serializer_.Lazy(fn() {\n`);
        this.push(`${typeSpeller.getFieldSerializerExpression(field)}\n`);
        this.push(`}),\n`);
      } else {
        this.push(
          `serializer: struct_serializer_.Eager(${fieldName}_serializer),\n`,
        );
      }
      this.push(`),\n`);
    }
    this.push(`],\n`);
    this.push(`default: ${structDefaultExpr},\n`);
    this.push(`get_unrecognized: fn(s) { s.unrecognized_ },\n`);
    const setUnrecognizedBody =
      struct.record.fields.length === 0
        ? `${typeName}(unrecognized_: u)`
        : `${typeName}(..s, unrecognized_: u)`;
    const setUnrecognizedArg = struct.record.fields.length === 0 ? `_s` : `s`;
    this.push(
      `set_unrecognized: fn(${setUnrecognizedArg}, u) { ${setUnrecognizedBody} },\n`,
    );
    this.push(
      `removed_numbers: [${struct.record.removedNumbers.join(", ")}],\n`,
    );
    this.push(
      `recognized_slot_count: ${struct.record.numSlotsInclRemovedNumbers},\n`,
    );

    // Generate decode_dense_json callback
    const numSlots = struct.record.numSlotsInclRemovedNumbers;
    const fieldsBySlot = new Map(fieldsByNumber.map((f) => [f.number, f]));

    this.push(`decode_dense_json: fn(arr, keep) {\n`);
    for (let slot = 0; slot < numSlots; slot++) {
      const field = fieldsBySlot.get(slot);
      if (field) {
        this.neededModules.add("gleam/dynamic/decode");
        const varName = toFieldName(field.name.text);
        const defExpr = typeSpeller.getFieldDefaultExpression(field);
        const serExpr =
          field.isRecursive === false
            ? `${varName}_serializer`
            : typeSpeller.getFieldSerializerExpression(field);
        this.push(`use #(${varName}, arr) <- result_.try(case arr {\n`);
        this.push(`[] -> Ok(#(${defExpr}, []))\n`);
        this.push(
          `[elem, ..arr] -> decode_.run(elem, ${serExpr}.internal_adapter.decode_json(keep)) |> result_.map(fn(v) { #(v, arr) })\n`,
        );
        this.push(`})\n`);
      } else {
        this.push(`let arr = case arr { [] -> [] [_, ..arr] -> arr }\n`);
      }
    }
    this.push(
      `let unrecognized_ = struct_serializer_.make_unrecognized_fields_json(arr, list_.length(arr) + ${numSlots}, keep)\n`,
    );
    const structArgsDense =
      fieldArgLabels(fieldsByNumber) +
      (fieldsByNumber.length > 0 ? ", " : "") +
      "unrecognized_:";
    this.push(`Ok(${typeName}(${structArgsDense}))\n`);
    this.push(`},\n`);

    // Generate decode_binary callback
    const slotsToFillParam = numSlots > 0 ? "slots_to_fill" : "_slots_to_fill";
    const keepParam = fieldsByNumber.length > 0 ? "keep" : "_keep";
    this.push(`decode_binary: fn(bits, ${slotsToFillParam}, ${keepParam}) {\n`);
    for (let slot = 0; slot < numSlots; slot++) {
      const field = fieldsBySlot.get(slot);
      if (field) {
        const varName = toFieldName(field.name.text);
        const defExpr = typeSpeller.getFieldDefaultExpression(field);
        const serExpr =
          field.isRecursive === false
            ? `${varName}_serializer`
            : typeSpeller.getFieldSerializerExpression(field);
        this.push(
          `use #(${varName}, bits) <- result_.try(case slots_to_fill > ${slot} {\n`,
        );
        this.push(
          `active if active -> ${serExpr}.internal_adapter.decode(bits, keep)\n`,
        );
        this.push(`_ -> Ok(#(${defExpr}, bits))\n`);
        this.push(`})\n`);
      } else {
        this.push(
          `use bits <- result_.try(struct_serializer_.skip_binary_slot(bits, slots_to_fill > ${slot}))\n`,
        );
      }
    }
    const structArgsBin =
      fieldArgLabels(fieldsByNumber) +
      (fieldsByNumber.length > 0 ? ", " : "") +
      "unrecognized_: struct_serializer_.None";
    this.push(`Ok(#(${typeName}(${structArgsBin}), bits))\n`);
    this.push(`},\n`);

    this.push(`)\n`);
    this.push(`}\n\n`);
  }

  private writeTypesForEnum(record: RecordLocation): void {
    this.neededModules.add("skir_client");
    this.neededModules.add("skir_client/internal/enum_serializer");
    const { typeSpeller } = this;
    const typeName = this.typeNameFor(record);
    const fnPrefix = this.fnPrefixFor(record);
    const unknownCtorName =
      this.ctorNames.get(`${record.record.key}:__unknown__`) ??
      typeName + "Unknown";
    const variants = record.record.fields;

    this.pushSeparator(
      `enum ${record.recordAncestors.map((r) => r.name.text).join(".")}`,
    );

    // Doc comment.
    this.push(commentify(docToCommentText(record.record.doc)));

    // Type definition.
    // The Unknown variant is the only variant that may conflict with a
    // user-defined variant named "unknown"; this is documented as reserved.
    this.push(`pub type ${typeName} {\n`);
    this.push(
      `${unknownCtorName}(enum_serializer_.UnrecognizedVariant(${typeName}))\n`,
    );
    for (const variant of variants) {
      const ctorName =
        this.ctorNames.get(`${record.record.key}:${variant.name.text}`) ??
        typeName + convertCase(variant.name.text, "UpperCamel");
      this.push(commentify(docToCommentText(variant.doc)));
      if (variant.type) {
        const gleamType = typeSpeller.getGleamType(variant.type);
        this.push(`${ctorName}(${gleamType})\n`);
      } else {
        this.push(`${ctorName}\n`);
      }
    }
    this.push("}\n\n");

    // Default const — an enum defaults to the Unknown variant.
    this.push(`/// The default \`${typeName}\` (the unknown variant).\n`);
    this.push(
      `pub const ${fnPrefix}unknown = ${unknownCtorName}(enum_serializer_.None)\n\n`,
    );

    // Serializer.
    this.push(`/// Returns the serializer for \`${typeName}\` values.\n`);
    this.push(
      `pub fn ${fnPrefix}serializer() -> skir_client_.Serializer(${typeName}) {\n`,
    );
    this.push(`enum_serializer_.new_serializer(\n`);
    this.push(`name: ${JSON.stringify(record.record.name.text)},\n`);
    this.push(
      `qualified_name: ${JSON.stringify(record.recordAncestors.map((r) => r.name.text).join("."))},\n`,
    );
    this.push(`module_path: ${JSON.stringify(record.modulePath)},\n`);
    this.push(`doc: ${JSON.stringify(docToCommentText(record.record.doc))},\n`);
    this.push(`variants: [\n`);
    for (const variant of variants) {
      const ctorName =
        this.ctorNames.get(`${record.record.key}:${variant.name.text}`) ??
        typeName + convertCase(variant.name.text, "UpperCamel");
      if (!variant.type) {
        // Constant variant.
        this.push(`enum_serializer_.constant_variant(\n`);
        this.push(`name: ${JSON.stringify(variant.name.text)},\n`);
        this.push(`number: ${variant.number},\n`);
        this.push(`doc: ${JSON.stringify(docToCommentText(variant.doc))},\n`);
        this.push(`instance: ${ctorName},\n`);
        this.push(`),\n`);
      } else {
        // Wrapper variant.
        // Detect direct self-reference (recursive enum variant).
        const vType = variant.type!;
        const isDirectSelfRef =
          vType.kind === "record" && vType.key === record.record.key;
        this.neededModules.add("gleam/option");
        this.push(`enum_serializer_.wrapper_variant(\n`);
        this.push(`name: ${JSON.stringify(variant.name.text)},\n`);
        this.push(`number: ${variant.number},\n`);
        this.push(`doc: ${JSON.stringify(docToCommentText(variant.doc))},\n`);
        this.push(`serializer: fn() {\n`);
        this.push(`${typeSpeller.getSerializerExpression(variant.type)}\n`);
        this.push(`},\n`);
        if (isDirectSelfRef) {
          this.push(
            `type_sig: option_.Some(${typeSpeller.getTypeSignatureExpression(vType)}),\n`,
          );
        } else {
          this.push(`type_sig: option_.None,\n`);
        }
        this.push(`wrap: fn(v) { ${ctorName}(v) },\n`);
        this.push(`unwrap: fn(e) { let assert ${ctorName}(v) = e\n v },\n`);
        this.push(`),\n`);
      }
    }
    this.push(`],\n`);
    this.push(`unknown_default: ${fnPrefix}unknown,\n`);
    this.push(`get_kind_ordinal: fn(e) {\n`);
    this.push(`case e {\n`);
    this.push(`${unknownCtorName}(_) -> 0\n`);
    for (const [i, variant] of variants.entries()) {
      const ctorName =
        this.ctorNames.get(`${record.record.key}:${variant.name.text}`) ??
        typeName + convertCase(variant.name.text, "UpperCamel");
      const pattern = variant.type ? `${ctorName}(_)` : ctorName;
      this.push(`${pattern} -> ${i + 1}\n`);
    }
    this.push(`}\n`);
    this.push(`},\n`);
    this.push(`wrap_unrecognized: fn(u) { ${unknownCtorName}(u) },\n`);
    this.push(`get_unrecognized: fn(e) {\n`);
    this.push(`case e {\n`);
    this.push(`${unknownCtorName}(u) -> u\n`);
    if (variants.length > 0) {
      this.push(`_ -> enum_serializer_.None\n`);
    }
    this.push(`}\n`);
    this.push(`},\n`);
    this.push(
      `removed_numbers: [${record.record.removedNumbers.join(", ")}],\n`,
    );
    this.push(`)\n`);
    this.push(`}\n\n`);
  }

  /** Returns the `fnPrefix` for a record: ancestor names joined by `__`, with a trailing `_`. */
  private fnPrefixFor(record: RecordLocation): string {
    return (
      record.recordAncestors
        .map((a) => convertCase(a.name.text, "lower_underscore"))
        .join("__") + "_"
    );
  }

  /** Returns the unique Gleam type name for a record in this file context. */
  private typeNameFor(record: RecordLocation): string {
    return this.uniqueTypeNames.get(record.record.key) ?? getTypeName(record);
  }

  /** Returns the qualified prefix for a record: empty string if local, else `"alias."`. */
  private qualifiedPrefixFor(record: RecordLocation): string {
    return this.group.keySet.has(record.record.key)
      ? ""
      : `${this.keyToGroup.get(record.record.key)!.alias}.`;
  }

  private pushSeparator(header: string): void {
    this.push(`// ${"=".repeat(78)}\n`);
    this.push(`// ${header}\n`);
    this.push(`// ${"=".repeat(78)}\n\n`);
  }

  private push(...code: string[]): void {
    this.code += code.join("");
  }

  private joinLinesAndFixFormatting(): string {
    const indentUnit = "  ";
    let result = "";
    // The indent at every line is obtained by repeating indentUnit N times,
    // where N is the length of this array.
    const contextStack: Array<"{" | "(" | "[" | "<" | ":" | "."> = [];
    // Returns the last element in `contextStack`.
    const peekTop = (): string => contextStack.at(-1)!;
    const matchingLeft: Record<string, string> = {
      "}": "{",
      ")": "(",
      "]": "[",
      ">": "<",
    };
    for (let line of this.code.split("\n")) {
      line = line.trim();
      if (line.length <= 0) {
        // Don't indent empty lines.
        result += "\n";
        continue;
      }

      const firstChar = line[0];
      switch (firstChar) {
        case "}":
        case ")":
        case "]":
        case ">": {
          const left = matchingLeft[firstChar]!;
          while (contextStack.pop() !== left) {
            if (contextStack.length <= 0) {
              throw Error();
            }
          }
          break;
        }
        case ".": {
          if (peekTop() !== ".") {
            contextStack.push(".");
          }
          break;
        }
      }
      let indent = indentUnit.repeat(contextStack.length);
      if (line.startsWith("*")) {
        // Docstring: make sure the stars are aligned.
        indent += " ";
      }
      result += `${indent}${line}\n`;
      if (line.startsWith("//")) {
        continue;
      }
      const lastChar = line.slice(-1);
      switch (lastChar) {
        case "{":
        case "(":
        case "[":
        case "<": {
          // The next line will be indented
          contextStack.push(lastChar);
          break;
        }
        case ":":
        case "=": {
          if (peekTop() !== ":") {
            contextStack.push(":");
          }
          break;
        }
        case ";":
        case ",": {
          if (peekTop() === "." || peekTop() === ":") {
            contextStack.pop();
          }
        }
      }
    }

    return (
      result
        // Remove spaces enclosed within curly brackets if that's all there is.
        .replace(/\{\s+\}/g, "{}")
        // Remove spaces enclosed within round brackets if that's all there is.
        .replace(/\(\s+\)/g, "()")
        // Remove spaces enclosed within square brackets if that's all there is.
        .replace(/\[\s+\]/g, "[]")
        // Remove empty line following an open curly bracket.
        .replace(/(\{\n *)\n/g, "$1")
        // Remove empty line preceding a closed curly bracket.
        .replace(/\n(\n *\})/g, "$1")
        // Coalesce consecutive empty lines.
        .replace(/\n\n\n+/g, "\n\n")
        .replace(/\n\n$/g, "\n")
    );
  }
}

export const GENERATOR = new GleamCodeGenerator();

/**
 * Maps a list of fields to Gleam record constructor argument labels.
 * Returns a comma-joined string suitable for use in a constructor call.
 */
function fieldArgLabels(
  fields: ReadonlyArray<{ name: { text: string }; isRecursive: unknown }>,
): string {
  return fields
    .map((f) => {
      const varName = toFieldName(f.name.text);
      return `${varName}:`;
    })
    .join(", ");
}

function commentify(text: string): string {
  const trimmed = text.trim().replace(/\n{3,}/g, "\n\n");
  if (trimmed.length <= 0) {
    return "";
  }
  return trimmed
    .split("\n")
    .map((line) => (line.length > 0 ? `/// ${line}\n` : `///\n`))
    .join("");
}

function _mergeCommentSections(...sections: readonly string[]): string {
  return sections
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
    .join("\n\n");
}

function docToCommentText(doc: Doc): string {
  return doc.pieces
    .map((p) => {
      switch (p.kind) {
        case "text":
          return p.text;
        case "reference":
          return "`" + p.referenceRange.text.slice(1, -1) + "`";
      }
    })
    .join("");
}
