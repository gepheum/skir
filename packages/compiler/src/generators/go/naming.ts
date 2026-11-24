import { type Field, type RecordLocation, convertCase } from "skir-internal";

export function modulePathToPackageName(modulePath: string): string {
  return modulePath.replace(/^.*\//, "").replace(/\.skir$/, "");
}

export function modulePathToPackagePath(modulePath: string): string {
  return modulePath
    .replace(/^@/, "external/")
    .replace(/-/g, "_")
    .replace(/\.skir$/, "");
}

export function modulePathToAlias(modulePath: string): string {
  return modulePathToPackagePath(modulePath)
    .replace(/\//g, "_")
    .concat("_skir");
}

export function structFieldToGetterName(field: Field | string): string {
  const skirName = typeof field === "string" ? field : field.name.text;
  const upperCamel = convertCase(skirName, "UpperCamel");
  return skirName.startsWith("search_") ||
    skirName === "string" ||
    skirName === "to_builder"
    ? upperCamel.concat("_")
    : upperCamel;
}

/** Returns the name of the frozen Go struct for the given record. */
export function getClassName(record: RecordLocation): string {
  return record.recordAncestors.map((r) => r.name.text).join("_");
}
