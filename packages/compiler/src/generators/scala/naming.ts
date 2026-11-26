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

  structFieldToScalaName(field: Field | string): string {
    const skirName = typeof field === "string" ? field : field.name.text;
    const lowerCamel = convertCase(skirName, "lowerCamel");
    const nameConflict =
      SCALA_HARD_KEYWORDS.has(lowerCamel) ||
      TOP_LEVEL_PACKAGE_NAMES.has(lowerCamel) ||
      SCALA_OBJECT_SYMBOLS.has(lowerCamel) ||
      GENERATED_STRUCT_SYMBOLS.has(lowerCamel) ||
      lowerCamel === this.genPackageFirstName ||
      skirName.startsWith("mutable_");
    return nameConflict ? lowerCamel + "_" : lowerCamel;
  }

  /** Returns the name of the frozen Scala class for the given record. */
  getClassName(record: RecordLocation): ClassName {
    const { recordAncestors } = record;
    const parts: string[] = [];
    for (let i = 0; i < recordAncestors.length; ++i) {
      const ancestor = recordAncestors[i]!;
      let name = ancestor.name.text;
      const parent = i > 0 ? recordAncestors[i - 1]! : undefined;
      const parentType = parent?.recordType;
      if (
        (parentType === "struct" && STRUCT_NESTED_TYPE_NAMES.has(name)) ||
        (parentType === "enum" &&
          (ENUM_NESTED_TYPE_NAMES.has(name) ||
            /Wrapper$/.test(name) ||
            parent!.fields.some(
              (f) => !f.type && toEnumConstantName(f) === name,
            )))
      ) {
        name += "_";
      }
      parts.push(name);
    }

    const name = parts.at(-1)!;
    const pkg = this.modulePackage(record.modulePath);
    const qualifiedName = `_root_.${pkg}.${parts.join(".")}`;

    return { name, qualifiedName };
  }

  /** Returns the package of the Scala file generated for the given module. */
  modulePackage(modulePath: string): string {
    const importPath = modulePath
      .replace(/\.skir$/, "")
      .replace(/^@/, "external/")
      .replace(/-/g, "_")
      .split("/")
      .map((part) => (SCALA_HARD_KEYWORDS.has(part) ? `${part}_` : part))
      .join(".");
    return `${this.packagePrefix}skirout.${importPath}`;
  }

  /** Returns the last segment of the module's package name (for `private[pkg]`). */
  modulePackageLastSegment(modulePath: string): string {
    const pkg = this.modulePackage(modulePath);
    return pkg.split(".").at(-1)!;
  }
}

export const SCALA_HARD_KEYWORDS: ReadonlySet<string> = new Set([
  "abstract",
  "case",
  "catch",
  "class",
  "def",
  "do",
  "else",
  "enum",
  "export",
  "extends",
  "false",
  "final",
  "finally",
  "for",
  "forSome",
  "given",
  "if",
  "implicit",
  "import",
  "lazy",
  "macro",
  "match",
  "new",
  "null",
  "object",
  "override",
  "package",
  "private",
  "protected",
  "return",
  "sealed",
  "super",
  "then",
  "this",
  "throw",
  "trait",
  "true",
  "try",
  "type",
  "using",
  "val",
  "var",
  "while",
  "with",
  "yield",
]);

const TOP_LEVEL_PACKAGE_NAMES: ReadonlySet<string> = new Set<string>([
  "build",
  "java",
  "kotlin",
  "okio",
  "scala",
  "skirout",
]);

const SCALA_OBJECT_SYMBOLS: ReadonlySet<string> = new Set([
  "asInstanceOf",
  "clone",
  "eq",
  "equals",
  "finalize",
  "getClass",
  "hashCode",
  "isInstanceOf",
  "ne",
  "notify",
  "notifyAll",
  "synchronized",
  "toString",
  "wait",
]);

const GENERATED_STRUCT_SYMBOLS: ReadonlySet<string> = new Set([
  "copy",
  "toFrozen",
  "toMutable",
]);

export function toEnumConstantName(field: Field): string {
  const upperSnake = convertCase(field.name.text, "UPPER_UNDERSCORE");
  return upperSnake === "UNKNOWN" ? "UNKNOWN_" : upperSnake;
}

/** Returns the constant of the generated Kind enum for the given variant. */
export function getKindConstantName(variant: Field): string {
  return (
    convertCase(variant.name.text, "UPPER_UNDERSCORE") +
    (variant.type ? "_WRAPPER" : "_CONST")
  );
}

/** Returns the class generated for the given wrapper variant. */
export function getWrapperClassName(variant: Field): string {
  return convertCase(variant.name.text, "UpperCamel") + "Wrapper";
}

export interface ClassName {
  /** The name right after the 'class' keyword. */
  name: string;
  /**
   * Fully qualified class name starting with `_root_.`.
   * Examples: '_root_.skirout.foo.Foo', '_root_.skirout.foo.Foo.Bar'
   */
  qualifiedName: string;
}

/** Generated types nested within a struct companion object. */
const STRUCT_NESTED_TYPE_NAMES: ReadonlySet<string> = new Set(["Mutable"]);

/** Generated types nested within an enum companion object. */
const ENUM_NESTED_TYPE_NAMES: ReadonlySet<string> = new Set([
  "Kind",
  "Unknown",
]);
