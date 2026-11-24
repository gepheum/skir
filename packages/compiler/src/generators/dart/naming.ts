import {
  Constant,
  Field,
  Method,
  Module,
  RecordLocation,
  convertCase,
} from "skir-internal";

export function structFieldToDartName(field: Field | string): string {
  const skirName = typeof field === "string" ? field : field.name.text;
  const convertCaseResult = convertCase(skirName, "lowerCamel");
  return DART_KEYWORDS.has(convertCaseResult) ||
    DART_OBJECT_SYMBOLS.has(convertCaseResult) ||
    GENERATED_STRUCT_SYMBOLS.has(convertCaseResult) ||
    skirName.startsWith("mutable_")
    ? convertCaseResult + "_"
    : convertCaseResult;
}

export function enumVariantToDartName(variant: Field): string {
  const skirName = variant.name.text;
  const convertCaseResult = convertCase(skirName, "lowerCamel");
  return DART_KEYWORDS.has(convertCaseResult) ||
    DART_OBJECT_SYMBOLS.has(convertCaseResult) ||
    GENERATED_ENUM_SYMBOLS.has(convertCaseResult) ||
    skirName.startsWith("wrap_") ||
    skirName.startsWith("create_")
    ? convertCaseResult + "_"
    : convertCaseResult;
}

export function toLowerCamel(field: Field): string {
  const skirName = field.name.text;
  return convertCase(skirName, "lowerCamel");
}

export function toUpperCamel(field: Field): string {
  const skirName = field.name.text;
  return convertCase(skirName, "UpperCamel");
}

export function toTopLevelConstantName(constant: Constant): string {
  const skirName = constant.name.text;
  const convertCaseResult = convertCase(skirName, "lowerCamel");
  return DART_KEYWORDS.has(convertCaseResult) || skirName.endsWith("_METHOD")
    ? convertCaseResult + "_"
    : convertCaseResult;
}

/** Returns the name of the frozen Dart class for the given record. */
export function getClassName(
  record: RecordLocation,
  origin: {
    origin: Module;
  },
): string {
  const name = getUnqualifiedClassName(record);

  if (origin.origin.path === record.modulePath) {
    return name;
  } else {
    const alias = getModuleAlias(record.modulePath);
    return `${alias}.${name}`;
  }
}

/** Returns the name of the frozen Dart class within its own module. */
export function getUnqualifiedClassName(record: RecordLocation): string {
  return record.recordAncestors.map((r) => r.name.text).join("_");
}

/** Returns the name of the generated method descriptor. */
export function getMethodName(method: Method): string {
  return convertCase(method.name.text, "lowerCamel") + "Method";
}

/** Returns the constant of the generated kind enum for the given variant. */
export function getKindConstantName(variant: Field): string {
  return toLowerCamel(variant) + (variant.type ? "Wrapper" : "Const");
}

/** Returns the kind enum constant of the given variant within its own module. */
export function getKindName(record: RecordLocation, variant: Field): string {
  return `${getUnqualifiedClassName(record)}_kind.${getKindConstantName(variant)}`;
}

/** Returns the class generated for the given wrapper variant. */
export function getWrapperClassName(
  record: RecordLocation,
  variant: Field,
): string {
  return `${getUnqualifiedClassName(record)}_${toLowerCamel(variant)}Wrapper`;
}

/** Returns the factory that wraps a value into the given wrapper variant. */
export function getWrapFactoryName(variant: Field): string {
  return `wrap${toUpperCamel(variant)}`;
}

/** Returns the import URI of the Dart file generated for the given module. */
export function getModuleImportUri(
  importUriPrefix: string,
  modulePath: string,
): string {
  return importUriPrefix + modulePath.replace(/\.skir$/, ".dart");
}

export function getModuleAlias(modulePath: string): string {
  return (
    "_lib_" +
    modulePath
      .replace(/\.skir$/, "")
      .replace(/^@/, "external/")
      .replace(/[/-]/g, "_")
  );
}

const DART_KEYWORDS: ReadonlySet<string> = new Set([
  "abstract",
  "as",
  "assert",
  "async",
  "await",
  "break",
  "case",
  "catch",
  "class",
  "const",
  "continue",
  "covariant",
  "default",
  "deferred",
  "do",
  "dynamic",
  "else",
  "enum",
  "export",
  "extends",
  "extension",
  "external",
  "factory",
  "false",
  "final",
  "finally",
  "for",
  "Function",
  "get",
  "hide",
  "if",
  "implements",
  "import",
  "in",
  "interface",
  "is",
  "late",
  "library",
  "mixin",
  "new",
  "null",
  "on",
  "operator",
  "part",
  "required",
  "rethrow",
  "return",
  "set",
  "show",
  "static",
  "super",
  "switch",
  "sync",
  "this",
  "throw",
  "true",
  "try",
  "typedef",
  "var",
  "void",
  "while",
  "with",
  "yield",
]);

const DART_OBJECT_SYMBOLS: ReadonlySet<string> = new Set([
  "hashCode",
  "noSuchMethod",
  "runtimeType",
  "toString",
]);

const GENERATED_STRUCT_SYMBOLS: ReadonlySet<string> = new Set([
  "defaultInstance",
  "mutable",
  "serializer",
  "toFrozen",
  "toMutable",
]);

const GENERATED_ENUM_SYMBOLS: ReadonlySet<string> = new Set([
  "isUnknown",
  "kind",
  "serializer",
]);
