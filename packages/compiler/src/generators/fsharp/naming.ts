import { convertCase, type Field, type RecordLocation } from "skir-internal";

const FSHARP_KEYWORDS = new Set<string>([
  // F# reserved keywords
  "abstract",
  "and",
  "as",
  "assert",
  "base",
  "begin",
  "class",
  "default",
  "delegate",
  "do",
  "done",
  "downcast",
  "downto",
  "elif",
  "else",
  "end",
  "exception",
  "extern",
  "false",
  "finally",
  "fixed",
  "for",
  "fun",
  "function",
  "global",
  "if",
  "in",
  "inherit",
  "inline",
  "interface",
  "internal",
  "lazy",
  "let",
  "match",
  "member",
  "module",
  "mutable",
  "namespace",
  "new",
  "not",
  "null",
  "of",
  "open",
  "or",
  "override",
  "private",
  "public",
  "rec",
  "return",
  "select",
  "static",
  "struct",
  "then",
  "to",
  "true",
  "try",
  "type",
  "upcast",
  "use",
  "val",
  "void",
  "when",
  "while",
  "with",
  "yield",
  // F# future reserved keywords
  "asr",
  "land",
  "lor",
  "lsl",
  "lsr",
  "lxor",
  "mod",
  "sig",
  "atomic",
  "break",
  "checked",
  "component",
  "const",
  "constraint",
  "constructor",
  "continue",
  "eager",
  "event",
  "external",
  "functor",
  "include",
  "method",
  "mixin",
  "object",
  "parallel",
  "process",
  "protected",
  "pure",
  "sealed",
  "tailcall",
  "trait",
  "virtual",
  "volatile",
]);

const STRUCT_RESERVED_MEMBERS = new Set<string>([
  "Default",
  "Serializer",
  "Create",
  "Equals",
  "GetHashCode",
  "ToString",
  "GetType",
  "MemberwiseClone",
]);

const ENUM_RESERVED_CASES = new Set<string>([
  "Unknown",
  "UnknownDefault",
  "Default",
  "Serializer",
  "Kind",
  "Kind_",
  "KindType",
  "KindType_",
  "Equals",
  "GetHashCode",
  "ToString",
  "GetType",
  "MemberwiseClone",
]);

function escapeIdentifier(name: string): string {
  return FSHARP_KEYWORDS.has(name) ? `${name}_` : name;
}

function toTypeSegment(rawName: string): string {
  const upperCamel = convertCase(rawName, "UpperCamel");
  const escaped = escapeIdentifier(upperCamel);
  return escaped.length > 0 ? escaped : "_";
}

/**
 * Derives an F# top-level module name from a skir module path.
 * Examples:
 *   "full_name.skir"     -> "Skirout_FullName"
 *   "vehicles/car.skir"  -> "Skirout_Vehicles_Car"
 *   "@foo/bar/baz.skir"  -> "Skirout_External_Foo_Bar_Baz"
 */
export function modulePathToFsharpModuleName(modulePath: string): string {
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
 * Returns the flattened F# type name for a record.
 * Example: Outer.Inner.Deep -> Outer_Inner_Deep
 */
export function getTypeName(record: RecordLocation): string {
  const parts: string[] = [];
  for (const ancestor of record.recordAncestors) {
    let current = toTypeSegment(ancestor.name.text);
    if (
      parts.length === 0 &&
      (current === "Consts" ||
        current === "Methods" ||
        current === "ModuleInit")
    ) {
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

export function toFieldPropertyName(
  field: Field,
  enclosingTypeName: string,
): string {
  const base = toTypeSegment(field.name.text);
  if (
    STRUCT_RESERVED_MEMBERS.has(base) ||
    base === enclosingTypeName ||
    base.startsWith("_")
  ) {
    return `${base}_`;
  }
  return base;
}

export function toFieldParamName(field: Field): string {
  const lowerCamel = convertCase(field.name.text, "lowerCamel");
  if (
    FSHARP_KEYWORDS.has(lowerCamel) ||
    lowerCamel === "this" ||
    lowerCamel === "self"
  ) {
    return `${lowerCamel}_`;
  }
  return lowerCamel;
}

export function toVariantCaseName(
  variant: Field,
  enclosingTypeName: string,
): string {
  let name = toTypeSegment(variant.name.text);
  if (ENUM_RESERVED_CASES.has(name) || name === enclosingTypeName) {
    name = `${name}_`;
  }
  return name;
}
