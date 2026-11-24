import { type Field, type RecordLocation, convertCase } from "skir-internal";

export class Namer {
  private readonly genPackageFirstName: string;

  constructor(private readonly packagePrefix: string) {
    if (packagePrefix.length <= 0) {
      this.genPackageFirstName = "skirout";
    } else {
      this.genPackageFirstName = packagePrefix.split(".")[0]!;
    }
  }

  structFieldToKotlinName(field: Field | string): string {
    const skirName = typeof field === "string" ? field : field.name.text;
    const lowerCamel = convertCase(skirName, "lowerCamel");
    const nameConflict =
      KOTLIN_HARD_KEYWORDS.has(lowerCamel) ||
      TOP_LEVEL_PACKAGE_NAMES.has(lowerCamel) ||
      KOTLIN_OBJECT_SYMBOLS.has(lowerCamel) ||
      GENERATED_STRUCT_SYMBOLS.has(lowerCamel) ||
      lowerCamel === this.genPackageFirstName ||
      skirName.startsWith("mutable_");
    return nameConflict ? lowerCamel + "_" : lowerCamel;
  }

  /** Returns the name of the frozen Kotlin class for the given record. */
  getClassName(record: RecordLocation): ClassName {
    const { recordAncestors } = record;
    const parts: string[] = [];
    for (let i = 0; i < recordAncestors.length; ++i) {
      const record = recordAncestors[i]!;
      let name = record.name.text;
      const parentType = i > 0 ? recordAncestors[i - 1]!.recordType : undefined;
      if (
        (parentType === "struct" && STRUCT_NESTED_TYPE_NAMES.has(name)) ||
        (parentType === "enum" &&
          (ENUM_NESTED_TYPE_NAMES.has(name) || /[a-z]Wrapper$/.test(name)))
      ) {
        name += "_";
      }
      parts.push(name);
    }

    const name = parts.at(-1)!;

    const qualifiedName = `${this.modulePackage(record.modulePath)}.${parts.join(".")}`;

    return { name, qualifiedName };
  }

  /** Returns the package of the Kotlin file generated for the given module. */
  modulePackage(modulePath: string): string {
    const importPath = modulePath
      .replace(/\.skir$/, "")
      .replace(/^@/, "external/")
      .replace(/-/g, "_")
      .replace(/\//g, ".");
    return `${this.packagePrefix}skirout.${importPath}`;
  }
}

const KOTLIN_HARD_KEYWORDS: ReadonlySet<string> = new Set([
  "abstract",
  "annotation",
  "as",
  "break",
  "catch",
  "class",
  "const",
  "continue",
  "crossinline",
  "data",
  "else",
  "enum",
  "external",
  "final",
  "finally",
  "for",
  "fun",
  "if",
  "import",
  "in",
  "inline",
  "interface",
  "internal",
  "is",
  "lateinit",
  "noinline",
  "object",
  "open",
  "operator",
  "override",
  "package",
  "private",
  "protected",
  "public",
  "reified",
  "return",
  "sealed",
  "super",
  "suspend",
  "this",
  "throw",
  "try",
  "typealias",
  "val",
  "var",
  "when",
  "while",
]);

const TOP_LEVEL_PACKAGE_NAMES: ReadonlySet<string> = new Set<string>([
  "build",
  "java",
  "kotlin",
  "okio",
]);

const KOTLIN_OBJECT_SYMBOLS: ReadonlySet<string> = new Set([
  "equals",
  "hashCode",
  "toString",
  "javaClass",
]);

const GENERATED_STRUCT_SYMBOLS: ReadonlySet<string> = new Set([
  "copy",
  "toFrozen",
  "toMutable",
]);

export function toEnumConstantName(field: Field): string {
  return convertCase(field.name.text, "UPPER_UNDERSCORE");
}

/** Returns the constant of the generated Kind enum for the given variant. */
export function getKindConstantName(variant: Field): string {
  return toEnumConstantName(variant) + (variant.type ? "_WRAPPER" : "_CONST");
}

/** Returns the class generated for the given wrapper variant. */
export function getWrapperClassName(variant: Field): string {
  return convertCase(variant.name.text, "UpperCamel") + "Wrapper";
}

export interface ClassName {
  /** The name right after the 'class' keyword.. */
  name: string;
  /**
   * Fully qualified class name.
   * Examples: 'skirout.Foo', 'skirout.Foo.Bar'
   */
  qualifiedName: string;
}

/** Generated types nested within a struct class. */
const STRUCT_NESTED_TYPE_NAMES: ReadonlySet<string> = new Set(["Mutable"]);

/** Generated types nested within an enum class. */
const ENUM_NESTED_TYPE_NAMES: ReadonlySet<string> = new Set([
  "Kind",
  "Unknown",
]);
