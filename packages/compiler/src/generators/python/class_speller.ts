import type { Module, RecordLocation } from "skir-internal";

export interface ClassName {
  /** The name right after the 'class' keyword.. */
  name: string;
  /**
   * Fully qualified class name relative to a given module.
   * Examples: 'Foo', 'Foo.Bar', 'other.module.Foo.Bar'.
   */
  qualifiedName: string;
}

/** Returns the name of the frozen Python class for the given record. */
export function getClassName(
  record: RecordLocation,
  origin: Module,
  config: {
    packagePrefix?: string;
  },
): ClassName {
  const { recordAncestors } = record;
  const parts: string[] = [];
  for (let i = 0; i < recordAncestors.length; ++i) {
    const record = recordAncestors[i]!;
    let name = record.name.text;
    const parentType = i > 0 ? recordAncestors[i - 1]!.recordType : undefined;
    if (
      PY_UPPER_CAMEL_KEYWORDS.has(name) ||
      (parentType === "struct" && STRUCT_NESTED_TYPE_NAMES.has(name)) ||
      (parentType === "enum" && ENUM_NESTED_TYPE_NAMES.has(name))
    ) {
      name += "_";
    }
    parts.push(name);
  }

  const name = parts.at(-1)!;
  let qualifiedName = parts.join(".");

  if (record.modulePath !== origin.path) {
    // The record is located in an imported module.
    const path = record.modulePath;
    const importPath = normalizeModulePath(path, "py_module_name");
    const packagePrefix = config.packagePrefix ?? "";
    qualifiedName = `${packagePrefix}${importPath}.${qualifiedName}`;
  }

  return {
    name: name,
    qualifiedName: qualifiedName,
  };
}

/** Python keywords in UpperCamel format. */
export const PY_UPPER_CAMEL_KEYWORDS: ReadonlySet<string> = new Set<string>([
  "None",
  "False",
  "True",
]);

/** Generated types nested within a struct class. */
const STRUCT_NESTED_TYPE_NAMES: ReadonlySet<string> = new Set([
  "Mutable",
  "OrMutable",
]);

/** Generated types nested within an enum class. */
const ENUM_NESTED_TYPE_NAMES: ReadonlySet<string> = new Set(["Kind"]);

export function normalizeModulePath(
  path: string,
  to: "py_file_path" | "py_module_name",
): string {
  const base = path.replace(/-/g, "_").replace(/^@/, "external/");
  if (to === "py_file_path") {
    return base.replace(/\.skir$/, "_skir.py");
  } else {
    const _: "py_module_name" = to;
    return (
      "skirout." + base.replace(/\.skir$/, "").replace(/\//g, ".") + "_skir"
    );
  }
}
