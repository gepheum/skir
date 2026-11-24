import {
  Constant,
  Method,
  Record,
  RecordLocation,
  convertCase,
} from "skir-internal";

export function modulePathToCaselessEnumName(modulePath: string): string {
  return modulePath
    .replace(/^@/, "external/")
    .replace(/\.skir$/, "")
    .split("/")
    .map((part) => convertCase(part.replace(/-/g, "_"), "UpperCamel"))
    .join("_")
    .concat("_skir");
}

/** Returns the name of the Swift type for the given Skir record. */
export function getTypeName(record: Record): string {
  const name = record.name.text;
  return RESERVED_KEYWORDS.has(name) || SWIFT_MODULE_DEPS.has(name)
    ? name.concat("_")
    : name;
}

/** Returns the name of the Swift type for the given Skir method. */
export function getSwiftMethodName(method: Method): string {
  const name = method.name.text;
  return RESERVED_KEYWORDS.has(name) || SWIFT_MODULE_DEPS.has(name)
    ? name.concat("_")
    : name;
}

export type ModuleContext = {
  readonly kind: "module";
  readonly modulePath: string;
};

export function getTypeRef(
  record: RecordLocation,
  context: RecordLocation | ModuleContext | null,
): string {
  if (record.modulePath === context?.modulePath) {
    const recordAncestors = record.recordAncestors;
    const contextAncestors =
      context.kind === "module" ? [] : context.recordAncestors;
    // First, check if 'record' is nested within 'context'.
    // If so, we have a match.
    if (
      context.kind === "module" ||
      recordAncestors.slice(0, -1).some((a) => a === context.record)
    ) {
      return recordAncestors
        .slice(contextAncestors.length)
        .map((r) => getTypeName(r))
        .join(".");
    }
    // Then, climb back the ancestors of 'context' and look for a match with
    // the most outer ancestor of 'record'.
    const recordTopAncestor = recordAncestors[0]!;
    let nameConflict = false;
    for (const contextAncestor of [...contextAncestors].reverse()) {
      if (contextAncestor.nameToDeclaration[recordTopAncestor.name.text]) {
        // Name conflict: the context ancestor has a declaration with the same
        // name as the most outer ancestor of the record. In this case, we can't
        // use a concise reference.
        nameConflict = true;
        break;
      }
      if (contextAncestor === recordTopAncestor) {
        break;
      }
    }
    if (!nameConflict) {
      // In the same module and no name conflict: we don't have to return the
      // full-qualified name.
      return recordAncestors.map((r) => getTypeName(r)).join(".");
    }
  }
  return getQualifiedTypeName(record);
}

export function getQualifiedTypeName(record: RecordLocation): string {
  const caselessEnumName = modulePathToCaselessEnumName(record.modulePath);
  return [
    caselessEnumName,
    ...record.recordAncestors.map((r) => getTypeName(r)),
  ].join(".");
}

export function getSwiftFieldName(
  skirName: string,
  fieldRecursivity?: false | "soft" | "via-optional" | "hard",
): string {
  const upperName = convertCase(skirName, "lowerCamel");
  if (fieldRecursivity === "hard") {
    return `_${upperName}_rec`;
  } else if (
    RESERVED_KEYWORDS.has(upperName) ||
    GENERARATED_STRUCT_MEMBERS.has(upperName)
  ) {
    return upperName.concat("_");
  } else {
    return upperName;
  }
}

export function isValidVariantName(lowerCamelName: string): boolean {
  return (
    !RESERVED_KEYWORDS.has(lowerCamelName) &&
    !GENERARATED_ENUM_MEMBERS.has(lowerCamelName)
  );
}

export function getSwiftConstantName(constant: Constant): string {
  const lowerCamelName = convertCase(constant.name.text, "lowerCamel");
  return RESERVED_KEYWORDS.has(lowerCamelName)
    ? lowerCamelName.concat("_")
    : lowerCamelName;
}

const RESERVED_KEYWORDS = new Set<string>([
  // Keywords used in declarations.
  "associatedtype",
  "class",
  "deinit",
  "enum",
  "extension",
  "fileprivate",
  "func",
  "import",
  "init",
  "inout",
  "internal",
  "let",
  "open",
  "operator",
  "private",
  "protocol",
  "public",
  "rethrows",
  "static",
  "struct",
  "subscript",
  "typealias",
  "var",

  // Keywords used in statements.
  "break",
  "case",
  "continue",
  "default",
  "defer",
  "do",
  "else",
  "fallthrough",
  "for",
  "guard",
  "if",
  "in",
  "repeat",
  "return",
  "switch",
  "where",
  "while",

  // Keywords used in expressions and types.
  "Any",
  "as",
  "catch",
  "false",
  "is",
  "nil",
  "Self",
  "self",
  "super",
  "throw",
  "throws",
  "true",
  "try",

  // Contextual / special-purpose keywords that commonly conflict with identifiers.
  "actor",
  "any",
  "associativity",
  "async",
  "await",
  "borrowing",
  "convenience",
  "consuming",
  "didSet",
  "distributed",
  "dynamic",
  "final",
  "get",
  "indirect",
  "infix",
  "isolated",
  "lazy",
  "left",
  "mutating",
  "none",
  "nonmutating",
  "optional",
  "override",
  "package",
  "postfix",
  "precedence",
  "prefix",
  "Protocol",
  "required",
  "right",
  "set",
  "some",
  "Type",
  "unowned",
  "weak",
  "willSet",
]);

const SWIFT_MODULE_DEPS = new Set<string>([
  "Foundation",
  "SkirClient",
  "Swift",
]);

const GENERARATED_STRUCT_MEMBERS = new Set<string>([
  "copy",
  "defaultValue",
  "description",
  "partial",
  "serializer",
]);

const GENERARATED_ENUM_MEMBERS = new Set<string>([
  "description",
  "kind",
  "serializer",
  "unknown",
  "unknownValue",
]);
