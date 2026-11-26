import type { Module, RecordLocation } from "skir-internal";
import { convertCase } from "skir-internal";

export interface ClassName {
  /** The name right after the 'class' keyword. */
  name: string;
  /**
   * Relative qualified class name within its module.
   * Examples: 'Foo', 'Foo::Bar'.
   */
  relativeQualifiedName: string;
  /**
   * Fully qualified class name in Ruby.
   * If in the same module, equals relativeQualifiedName.
   * If in an imported module, includes the module prefix, e.g. 'Skirout::OtherSkir::Foo::Bar'.
   */
  qualifiedName: string;
  /**
   * Always includes the full Ruby module path, e.g. 'Skirout::MyModuleSkir::Foo::Bar'.
   */
  fullRubyQualname: string;
}

export function getClassName(
  record: RecordLocation,
  origin: Module,
  config: {
    modulePrefix?: string;
  },
): ClassName {
  const { recordAncestors } = record;
  const parts: string[] = [];
  for (let i = 0; i < recordAncestors.length; ++i) {
    const rec = recordAncestors[i]!;
    let name = rec.name.text;
    const parentType = i > 0 ? recordAncestors[i - 1]!.recordType : undefined;
    if (
      RUBY_UPPER_CAMEL_KEYWORDS.has(name) ||
      (parentType === "struct" && STRUCT_NESTED_TYPE_NAMES.has(name)) ||
      (parentType === "enum" && ENUM_NESTED_TYPE_NAMES.has(name)) ||
      name.startsWith("V_")
    ) {
      name += "_";
    }
    parts.push(name);
  }

  const name = parts.at(-1)!;
  const relativeQualifiedName = parts.join("::");
  const modulePathNames = getRubyModulePath(record.modulePath, config);
  const fullRubyQualname = [...modulePathNames, relativeQualifiedName].join(
    "::",
  );
  const qualifiedName = `::${fullRubyQualname}`;

  return {
    name,
    relativeQualifiedName,
    qualifiedName,
    fullRubyQualname,
  };
}

/** Reserved constant names in Ruby / Sorbet. */
export const RUBY_UPPER_CAMEL_KEYWORDS: ReadonlySet<string> = new Set<string>([
  "BEGIN",
  "END",
  "True",
  "False",
  "Nil",
  "Object",
  "BasicObject",
  "Module",
  "Class",
  "Kernel",
  "NilClass",
  "TrueClass",
  "FalseClass",
  "T",
  "Skir",
  "Skirout",
]);

/** Generated types/constants nested within a struct class. */
const STRUCT_NESTED_TYPE_NAMES: ReadonlySet<string> = new Set([
  "Mutable",
  "OrMutable",
  "DEFAULT",
]);

/** Generated types/constants nested within an enum class. */
const ENUM_NESTED_TYPE_NAMES: ReadonlySet<string> = new Set([
  "Kind",
  "Union",
  "UNKNOWN",
]);

export function normalizeModuleFilePath(path: string): string {
  const base = path.replace(/-/g, "_").replace(/^@/, "external/");
  return base.replace(/\.skir$/, "_skir.rb");
}

export function getRubyModulePath(
  path: string,
  config: {
    modulePrefix?: string;
  },
): string[] {
  const prefixParts = (config.modulePrefix ?? "")
    .split("::")
    .filter((p) => p.length > 0);
  const base = path
    .replace(/-/g, "_")
    .replace(/^@/, "external/")
    .replace(/\.skir$/, "_skir");
  const segments = base.split("/").map((s) => convertCase(s, "UpperCamel"));
  return [...prefixParts, "Skirout", ...segments];
}
