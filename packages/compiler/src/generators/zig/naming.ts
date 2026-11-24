import { type Field, type RecordLocation, convertCase } from "skir-internal";

export function modulePathToOutputPath(modulePath: string): string {
  return modulePath
    .replace(/^@/, "external/")
    .replace(/-/g, "_")
    .replace(/\.skir$/, ".zig");
}

export function modulePathToImportAlias(modulePath: string): string {
  const outputPath = modulePathToOutputPath(modulePath).replace(/\.zig$/, "");
  const components = outputPath
    .split("/")
    .map((c) => c.replace(/[^A-Za-z0-9]/g, "_"));
  return `_x_${components.join("__")}`;
}

export function getTypeName(record: RecordLocation): string {
  return record.recordAncestors
    .map((ancestor, index, ancestors) =>
      getDeclaredTypeNameSegment(
        ancestor.name.text,
        ancestors[index - 1] ?? null,
      ),
    )
    .join(".");
}

export function getDeclaredTypeName(record: RecordLocation): string {
  const parentRecord =
    record.recordAncestors[record.recordAncestors.length - 2] ?? null;
  return getDeclaredTypeNameSegment(record.record.name.text, parentRecord);
}

export function toTypeName(input: string): string {
  const name = convertCase(input, "UpperCamel");
  return RESERVED_TYPE_NAMES.has(name) ? `${name}Type` : name;
}

export function toStructFieldName(input: string): string {
  const name = convertCase(input, "lower_underscore");
  if (name === "_unrecognized") {
    return "_unrecognized_";
  }
  if (
    name === "default" ||
    name === "serializer" ||
    name === "clone" ||
    RESERVED_LOWER_NAMES.has(name)
  ) {
    return `${name}_`;
  } else {
    return name;
  }
}

export function toFieldGetterName(field: Field | string): string {
  const source = typeof field === "string" ? field : field.name.text;
  const name = `get${convertCase(source, "UpperCamel")}`;
  return RESERVED_METHOD_NAMES.has(name) ? `${name}Value` : name;
}

export function toVariantName(input: string): string {
  const name = convertCase(input, "UpperCamel");
  return RESERVED_TYPE_NAMES.has(name) ? `${name}_` : name;
}

export function toConstantName(input: string): string {
  const name = `${convertCase(input, "lower_underscore")}_const`;
  return RESERVED_LOWER_NAMES.has(name) ? `${name}_value` : name;
}

export function toMethodFnName(input: string): string {
  const name = `${convertCase(input, "lower_underscore")}_method`;
  return RESERVED_LOWER_NAMES.has(name) ? `${name}_fn` : name;
}

function getDeclaredTypeNameSegment(
  input: string,
  parentRecord: RecordLocation["record"] | null,
): string {
  const rawName = convertCase(input, "UpperCamel");
  if (parentRecord?.recordType === "enum") {
    const matchingVariantName = getMatchingVariantName(parentRecord, input);
    if (matchingVariantName === `${rawName}_`) {
      return `${rawName}__`;
    }
    if (
      rawName === "Kind" ||
      rawName === "Unknown" ||
      matchingVariantName === rawName
    ) {
      return `${rawName}_`;
    }
  }
  return toTypeName(input);
}

function getMatchingVariantName(
  record: RecordLocation["record"],
  input: string,
): string | null {
  for (const key of [
    convertCase(input, "lower_underscore"),
    convertCase(input, "UPPER_UNDERSCORE"),
  ]) {
    const declaration = record.nameToDeclaration[key];
    if (declaration?.kind === "field") {
      return toVariantName(declaration.name.text);
    }
  }
  return null;
}

const RESERVED_LOWER_NAMES = new Set<string>([
  "addrspace",
  "align",
  "allowzero",
  "and",
  "anyframe",
  "anytype",
  "asm",
  "async",
  "await",
  "break",
  "callconv",
  "catch",
  "comptime",
  "const",
  "continue",
  "defer",
  "else",
  "enum",
  "errdefer",
  "error",
  "export",
  "extern",
  "false",
  "fn",
  "for",
  "if",
  "inline",
  "linksection",
  "noalias",
  "nosuspend",
  "null",
  "opaque",
  "or",
  "orelse",
  "packed",
  "pub",
  "resume",
  "return",
  "linksection",
  "struct",
  "suspend",
  "switch",
  "test",
  "threadlocal",
  "true",
  "try",
  "union",
  "unreachable",
  "usingnamespace",
  "var",
  "volatile",
  "while",
]);

const RESERVED_TYPE_NAMES = new Set<string>([
  "AnyType",
  "default",
  "DEFAULT",
  "Default",
  "Kind",
  "Self",
  "Unknown",
  "Void",
]);

const RESERVED_METHOD_NAMES = new Set<string>(["defaultRef", "kind"]);
