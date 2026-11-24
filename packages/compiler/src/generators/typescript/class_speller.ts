import type { Module, RecordLocation } from "skir-internal";

export interface ClassName {
  /**
   * Name of the TypeScript class, e.g. "Bar". It is obtained by taking the
   * record name, as specified in the '.skir' file, and appending one or
   * multiple underscores if there is a conflict with another name.
   * If the class is nested, the `name` does not include the name of the parent
   * classes.
   */
  readonly name: string;
  /**
   * Qualified type name, e.g. "Foo.Bar".
   * This is what you want to use in type declarations.
   */
  readonly type: string;
  /**
   * Class expression, e.g. "Foo_Bar" if the class is defined in the same
   * module, or "x_other_module.Foo.Bar" if it is defined in a different module.
   * This is what you want to use in the TypeScript code that gets transpiled to
   * Javascript.
   */
  readonly value: string;
  /**
   * Expression referring to the parent class if this class is nested, undefined
   * otherwise.
   */
  parentClassValue: string | undefined;
  /**
   * Name of the record, as specified in the '.skir' file. This can be different
   * from `name` if for example the record name conflicts with a built-in class.
   * If the record is nested, the `recordName` does not include the name of the
   * parent records.
   */
  readonly recordName: string;
  /**
   * Dot-separated record names, where the first record is a record defined at
   * the top-level, the last record is this record, and every record in the
   * chain is nested within the previous record.
   */
  readonly recordQualifiedName: string;

  readonly recordType: "struct" | "enum";
  /** True if the class is nested within another class. */
  readonly isNested: boolean;
}

/** Returns the name of the frozen TypeScript class for the given record. */
export function getClassName(
  record: RecordLocation,
  origin: Module,
): ClassName {
  const recordType = record.record.recordType;
  const { recordAncestors } = record;
  const isNested = recordAncestors.length >= 2;
  const seenNames = new Set<string>();
  const parts: string[] = [];
  for (let i = 0; i < recordAncestors.length; ++i) {
    const reservedNames =
      i === 0
        ? BUILTIN_TYPE_NAMES
        : recordAncestors[i - 1]!.recordType === "struct"
          ? STRUCT_NESTED_TYPE_NAMES
          : ENUM_NESTED_TYPE_NAMES;

    const record = recordAncestors[i]!;
    let name = record.name.text;

    while (seenNames.has(name) || reservedNames.has(name)) {
      name += "_";
    }

    parts.push(name);
    seenNames.add(name);
  }

  const name = parts.at(-1)!;
  const recordName = record.record.name.text;
  const recordQualifiedName = recordAncestors.map((r) => r.name.text).join(".");

  let type: string;
  let value: string;
  let parentClassValue: string | undefined;
  if (record.modulePath !== origin.path) {
    // The record is located in an imported module.
    const path = record.modulePath;
    const importedNames = origin.pathToImportedNames[path]!;
    if (importedNames.kind === "all") {
      const alias = importedNames.alias;
      type = [`x_${alias}`].concat(parts).join(".");
    } else {
      type = `${parts.join(".")}`;
    }
    value = type;
  } else {
    type = parts.join(".");
    value = parts.join("_");
    if (isNested) {
      parentClassValue = parts.slice(0, -1).join("_");
    }
  }

  return {
    name: name,
    type: type,
    value: value,
    parentClassValue: parentClassValue,
    recordName: recordName,
    recordQualifiedName: recordQualifiedName,
    recordType: recordType,
    isNested: isNested,
  };
}

export function maybeEscapeTopLevelUpperCaseName(name: string): string {
  return BUILTIN_TYPE_NAMES.has(name) ? `${name}_` : name;
}

const BUILTIN_TYPE_NAMES: ReadonlySet<string> = new Set([
  // Subset of the standard built-in Typescript types and Javascript class names
  // used in the generated code, either in the ".d.ts" file or the ".js" file.
  // We can't use those as names for generated declarations at the top-level.
  "Array",
  "BigInt",
  "Partial",
  "ReadonlyArray",
]);

/** Generated types nested within a struct namespace. */
const STRUCT_NESTED_TYPE_NAMES: ReadonlySet<string> = new Set([
  "Initializer",
  "Mutable",
  "OrMutable",
]);

/** Generated types nested within an enum namespace. */
const ENUM_NESTED_TYPE_NAMES: ReadonlySet<string> = new Set([
  "Initializer",
  "Kind",
  "Value",
  "UnionView",
]);
