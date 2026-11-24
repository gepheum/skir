import { Field, RecordLocation, convertCase } from "skir-internal";

export interface ClassName {
  /** The name right after the 'class' keyword. */
  name: string;
  /**
   * Fully qualified class name.
   * Examples: 'skirout.Foo', 'skirout.Foo.Bar'
   */
  qualifiedName: string;
}

export class Namer {
  private readonly genPackageFirstName: string;

  constructor(private readonly packagePrefix: string) {
    if (packagePrefix.length <= 0) {
      this.genPackageFirstName = "skirout";
    } else {
      this.genPackageFirstName = packagePrefix.split(".")[0]!;
    }
  }

  structFieldToJavaName(field: Field | string): string {
    const skirName = typeof field === "string" ? field : field.name.text;
    const lowerCamel = convertCase(skirName, "lowerCamel");
    const nameConflict =
      JAVA_HARD_KEYWORDS.has(lowerCamel) ||
      TOP_LEVEL_PACKAGE_NAMES.has(lowerCamel) ||
      JAVA_OBJECT_SYMBOLS.has(lowerCamel) ||
      GENERATED_STRUCT_SYMBOLS.has(lowerCamel) ||
      lowerCamel === this.genPackageFirstName;
    return nameConflict ? lowerCamel + "_" : lowerCamel;
  }

  /** Returns the name of the frozen Java class for the given record. */
  getClassName(record: RecordLocation): ClassName {
    const { recordAncestors } = record;
    const parts: string[] = [];
    const seenNames = new Set<string>();
    for (let i = 0; i < recordAncestors.length; ++i) {
      const record = recordAncestors[i]!;
      let name = record.name.text;
      if (
        name === "Kind" ||
        name === "Builder" ||
        /[^a-z]Wrapper$/.test(name) ||
        (i === 0 && (name === "Constants" || name === "Methods"))
      ) {
        name += "_";
      }
      while (seenNames.has(name)) {
        name += "_";
      }
      seenNames.add(name);
      parts.push(name);
    }

    const name = parts.at(-1)!;

    const path = record.modulePath;
    const importPath = path
      .replace(/\.skir$/, "")
      .replace(/^@/, "external/")
      .replace(/-/g, "_")
      .replace(/\//g, ".");
    const qualifiedName = `${this.packagePrefix}skirout.${importPath}.${parts.join(".")}`;

    return { name, qualifiedName };
  }
}

// TODO: update
const JAVA_HARD_KEYWORDS: ReadonlySet<string> = new Set([
  "abstract",
  "assert",
  "boolean",
  "break",
  "byte",
  "case",
  "catch",
  "char",
  "class",
  "const",
  "continue",
  "default",
  "do",
  "double",
  "else",
  "enum",
  "exports",
  "extends",
  "false",
  "final",
  "finally",
  "float",
  "for",
  "goto",
  "if",
  "implements",
  "import",
  "instanceof",
  "int",
  "interface",
  "long",
  "module",
  "native",
  "new",
  "null",
  "package",
  "private",
  "protected",
  "public",
  "return",
  "short",
  "static",
  "strictfp",
  "super",
  "switch",
  "synchronized",
  "this",
  "throw",
  "throws",
  "transient",
  "true",
  "try",
  "void",
  "volatile",
  "while",
  "with",
  "yield",
]);

const TOP_LEVEL_PACKAGE_NAMES: ReadonlySet<string> = new Set<string>([
  "build",
  "java",
  "kotlin",
  "land",
  "okio",
]);

const JAVA_OBJECT_SYMBOLS: ReadonlySet<string> = new Set([
  "clone",
  "equals",
  "finalize",
  "getClass",
  "hashCode",
  "notify",
  "notifyAll",
  "toString",
  "wait",
]);

const GENERATED_STRUCT_SYMBOLS: ReadonlySet<string> = new Set([
  "builder",
  "partialBuilder",
  "toBuilder",
]);

export function toEnumConstantName(field: Field): string {
  const skirName = convertCase(field.name.text, "UPPER_UNDERSCORE");
  return skirName === "SERIALIZER" || skirName === "TYPE_DESCRIPTOR"
    ? `${skirName}_`
    : skirName;
}
