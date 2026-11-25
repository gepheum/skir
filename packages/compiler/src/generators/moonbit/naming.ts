import { convertCase, Field, type RecordLocation } from "skir-internal";

export function modulePathToPackageDir(modulePath: string): string {
  return modulePath.replace(/\.skir$/, "");
}

export function modulePathToFileStem(modulePath: string): string {
  return modulePath.replace(/^.*\//, "").replace(/\.skir$/, "");
}

export function modulePathToAlias(modulePath: string): string {
  return "skirout_".concat(
    modulePathToPackageDir(modulePath)
      .replace(/^@/g, "external_")
      .replace(/[^a-zA-Z0-9]/g, "_")
      .concat("_skir"),
  );
}

export function getTypeName(record: RecordLocation): string {
  const candidate = record.recordAncestors.map((r) => r.name.text).join("_");
  return RESERVED_TYPE_NAMES.has(candidate) ? `${candidate}_` : candidate;
}

const RESERVED_TYPE_NAMES = new Set<string>([
  "Bool",
  "Byte",
  "Bytes",
  "Char",
  "Double",
  "Error",
  "Float",
  "Int",
  "Int16",
  "Int64",
  "String",
  "UInt",
  "UInt16",
  "UInt64",
  "Unit",
]);

export function getTypeNameLower(record: RecordLocation): string {
  const { recordAncestors } = record;
  return recordAncestors
    .map((r) => convertCase(r.name.text, "lower_underscore"))
    .join("__");
}

export function toStructFieldName(name: string): string {
  return isReservedIdentifier(name) ? `${name}_` : name;
}

export function getEnumFactoryMethodName(variant: Field): string {
  const candidate = convertCase(variant.name.text, "lower_underscore");
  return isReservedIdentifier(candidate) ||
    candidate === "serializer" ||
    candidate === "kind"
    ? `${candidate}_`
    : candidate;
}

function isReservedIdentifier(name: string): boolean {
  return RESERVED_IDENTIFIERS.has(name);
}

const RESERVED_IDENTIFIERS = new Set<string>([
  "and",
  "as",
  "break",
  "catch",
  "const",
  "continue",
  "derive",
  "else",
  "enum",
  "extern",
  "fn",
  "for",
  "guard",
  "if",
  "impl",
  "import",
  "in",
  "let",
  "loop",
  "match",
  "member",
  "mut",
  "or",
  "priv",
  "pub",
  "raise",
  "return",
  "struct",
  "test",
  "trait",
  "try",
  "type",
  "typealias",
  "while",
  "with",
]);
