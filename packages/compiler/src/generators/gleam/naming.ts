import { type RecordLocation, convertCase } from "skir-internal";

// Gleam keywords that cannot be used as identifiers.
const GLEAM_KEYWORDS = new Set([
  "as",
  "assert",
  "auto",
  "case",
  "const",
  "delegate",
  "derive",
  "echo",
  "else",
  "fn",
  "if",
  "implement",
  "import",
  "let",
  "macro",
  "opaque",
  "panic",
  "pub",
  "test",
  "todo",
  "type",
  "use",
]);

/**
 * Returns the simple Gleam type name for a record — just the last ancestor's UpperCamel name.
 * Each type lives in its own module, so no prefix from outer ancestors is needed.
 * e.g. FooBar → "FooBar", FooBar.ItemType → "ItemType", FooBar.ItemType.Equipment → "Equipment"
 */
export function getTypeName(record: RecordLocation): string {
  return convertCase(record.recordAncestors.at(-1)!.name.text, "UpperCamel");
}

/**
 * Returns the file-name segment for a record.
 * All ancestor names are converted to snake_case and joined with "__".
 * e.g. FooBar → "foo_bar", FooBar.ItemType → "foo_bar__item_type",
 *      FooBar.ItemType.Equipment → "foo_bar__item_type__equipment"
 */
export function getRecordFileSegment(record: RecordLocation): string {
  return record.recordAncestors
    .map((r) => convertCase(r.name.text, "lower_underscore"))
    .join("__");
}

/**
 * Returns the directory portion of a Skir module path.
 * Strips "@", converts "-" to "_", strips ".skir".
 * e.g. "@gepheum/skir-golden-tests/goldens.skir" → "gepheum/skir_golden_tests/goldens"
 */
export function getModuleDir(modulePath: string): string {
  return modulePath
    .replace(/^@/, "")
    .replace(/-/g, "_")
    .replace(/\.skir$/, "");
}

/**
 * Returns the Gleam output file path given a pre-computed module dir and file segment.
 * e.g. ("gepheum/skir_foo/bar", "foo__s") → "gepheum/skir_foo/bar/foo__s.gleam"
 */
export function segmentToGleamPath(moduleDir: string, segment: string): string {
  return `${moduleDir}/${segment}.gleam`;
}

/**
 * Returns the Gleam import path given a pre-computed module dir and file segment.
 * e.g. ("gepheum/skir_foo/bar", "foo__s") → "skirout/gepheum/skir_foo/bar/foo__s"
 */
export function segmentToGleamImportPath(
  moduleDir: string,
  segment: string,
): string {
  return `skirout/${moduleDir}/${segment}`;
}

/**
 * Returns the Gleam import alias given a pre-computed module dir and file segment.
 * Trailing underscore avoids name conflicts with user-defined types.
 * e.g. ("gepheum/skir_foo/bar", "foo__s") → "gepheum__skir_foo__bar__foo__s_"
 */
export function segmentToGleamAlias(
  moduleDir: string,
  segment: string,
): string {
  return `${moduleDir.replace(/\//g, "__")}__${segment}_`;
}

/**
 * Returns the Gleam output file path for a record (relative to outDir).
 * e.g. "@gepheum/skir-foo/bar.skir", FooBar.S → "gepheum/skir_foo/bar/foo_bar__s.gleam"
 */
export function recordToGleamPath(record: RecordLocation): string {
  return `${getModuleDir(record.modulePath)}/${getRecordFileSegment(record)}.gleam`;
}

/**
 * Returns the Gleam import path for a record (for use in an import statement).
 * e.g. "@gepheum/skir-foo/bar.skir", FooBar.S → "skirout/gepheum/skir_foo/bar/foo_bar__s"
 */
export function recordToGleamImportPath(record: RecordLocation): string {
  return `skirout/${getModuleDir(record.modulePath)}/${getRecordFileSegment(record)}`;
}

/**
 * Returns the Gleam import alias for a record.
 * Uses "__" between all path segments and between ancestor names.
 * e.g. "@gepheum/skir-foo/bar.skir", FooBar.S → "gepheum__skir_foo__bar__foo_bar__s"
 */
export function recordToGleamAlias(record: RecordLocation): string {
  return (
    getModuleDir(record.modulePath).replace(/\//g, "__") +
    "__" +
    getRecordFileSegment(record)
  );
}

/**
 * Converts a skir field name to a safe Gleam label (snake_case, appends "_" if keyword).
 */
export function toFieldName(skirName: string): string {
  const snake = convertCase(skirName, "lower_underscore");
  return GLEAM_KEYWORDS.has(snake) ? snake + "_" : snake;
}
