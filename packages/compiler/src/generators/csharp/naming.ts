import { convertCase, type Field, type RecordLocation } from "skir-internal";

const CSHARP_KEYWORDS = new Set<string>([
  "abstract",
  "as",
  "base",
  "bool",
  "break",
  "byte",
  "case",
  "catch",
  "char",
  "checked",
  "class",
  "const",
  "continue",
  "decimal",
  "default",
  "delegate",
  "do",
  "double",
  "else",
  "enum",
  "event",
  "explicit",
  "extern",
  "false",
  "finally",
  "fixed",
  "float",
  "for",
  "foreach",
  "goto",
  "if",
  "implicit",
  "in",
  "int",
  "interface",
  "internal",
  "is",
  "lock",
  "long",
  "namespace",
  "new",
  "null",
  "object",
  "operator",
  "out",
  "override",
  "params",
  "private",
  "protected",
  "public",
  "readonly",
  "ref",
  "return",
  "sbyte",
  "sealed",
  "short",
  "sizeof",
  "stackalloc",
  "static",
  "string",
  "struct",
  "switch",
  "this",
  "throw",
  "true",
  "try",
  "typeof",
  "uint",
  "ulong",
  "unchecked",
  "unsafe",
  "ushort",
  "using",
  "virtual",
  "void",
  "volatile",
  "while",
]);

// Members that are synthesized on every C# record and may not be re-declared.
const RECORD_SYNTHESIZED_MEMBERS = new Set<string>([
  "Clone",
  "Equals",
  "GetHashCode",
  "ToString",
  "PrintMembers",
  "Deconstruct",
]);

export const GENERATED_MEMBER_NAMES = new Set<string>([
  "Default",
  "Serializer",
]);

// Members synthesized inside generated enum record bodies.
const ENUM_RESERVED_MEMBER_NAMES = new Set<string>([
  "Unknown",
  "Kind",
  "Kind_",
  "KindType",
  "KindType_",
  "Value_",
  "Visitor",
  "Accept",
  "Serializer",
  "_initAdapter",
  "Adapter",
  "AdapterSerializer",
  ...RECORD_SYNTHESIZED_MEMBERS,
]);

function escapeIdentifier(name: string): string {
  return CSHARP_KEYWORDS.has(name) ? `${name}_` : name;
}

export function isRecordSynthesizedMember(name: string): boolean {
  return RECORD_SYNTHESIZED_MEMBERS.has(name);
}

function toTypeSegment(rawName: string): string {
  const upperCamel = convertCase(rawName, "UpperCamel");
  const escaped = escapeIdentifier(upperCamel);
  return escaped.length > 0 ? escaped : "_";
}

/**
 * Derives a C# namespace from a skir module path.
 * Examples:
 *   "full_name.skir"     -> "Skirout_FullName"
 *   "vehicles/car.skir" -> "Skirout_Vehicles_Car"
 */
export function modulePathToNamespace(modulePath: string): string {
  const segments = modulePath
    .replace(/^@/, "external/")
    .replace(/\.skir$/, "")
    .split("/");
  const pascal = segments
    .map((s) => toTypeSegment(s.replace(/-/g, "_")))
    .join("_");
  return `Skirout_${pascal}`;
}

/**
 * Returns the flattened C# type name for a record.
 * Example: Outer.Inner.Deep -> Outer_Inner_Deep
 */
export function getTypeName(record: RecordLocation): string {
  const parts: string[] = [];
  for (const ancestor of record.recordAncestors) {
    let current = toTypeSegment(ancestor.name.text);
    if (parts.length === 0 && (current === "Consts" || current === "Methods")) {
      current = current.concat("_");
    }
    const parent = parts.at(-1);
    if (parent === current) {
      current = `${current}_`;
    }
    parts.push(current);
  }
  return parts.join("_");
}

/** Returns the immediate C# type name of a record. */
export function getTypeSimpleName(record: RecordLocation): string {
  return getTypeName(record);
}

export function toFieldPropertyName(
  field: Field,
  enclosingTypeName: string,
): string {
  const base = toTypeSegment(field.name.text);
  if (
    GENERATED_MEMBER_NAMES.has(base) ||
    RECORD_SYNTHESIZED_MEMBERS.has(base) ||
    base === enclosingTypeName
  ) {
    return `${base}_`;
  }
  return base;
}

export function toVariantTypeName(variant: Field): string {
  let name = toTypeSegment(variant.name.text);
  if (ENUM_RESERVED_MEMBER_NAMES.has(name)) {
    name = `${name}_`;
  }
  if (!variant.type && /^(wrap_|as_)/i.test(variant.name.text)) {
    name = `${name}_`;
  }
  return name;
}

/**
 * Converts a skir module path to the corresponding C# output file path,
 * keeping path segment names in lower_case.
 * Examples:
 *   "full_name.skir"     -> "full_name.cs"
 *   "vehicles/car.skir" -> "vehicles/car.cs"
 *   "@foo/bar/baz.skir" -> "@foo/bar/baz.cs"
 */
export function modulePathToCsharpPath(modulePath: string): string {
  // Preserve a leading @scope/ prefix verbatim (external packages).
  const atMatch = modulePath.match(/^(@[^/]+\/)(.*)$/);
  const prefix = atMatch?.[1] ?? "";
  const rest = atMatch?.[2] ?? modulePath;

  const parts = rest.replace(/\.skir$/, "").split("/");
  const lowerSnake = parts
    .map((p) => p.replace(/-/g, "_").toLowerCase())
    .join("/");
  return `${prefix}${lowerSnake}.cs`;
}
