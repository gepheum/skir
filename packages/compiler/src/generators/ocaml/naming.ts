import { convertCase, type Field, type RecordLocation } from "skir-internal";

/**
 * Converts a .skir module path (e.g. "user.skir", "vehicles/car.skir",
 * "@gepheum/skir-fantasy-game-example/fantasy_game.skir") into a flat
 * OCaml file stem (e.g. "skirout_user", "skirout_vehicles__car",
 * "skirout__ext__gepheum__skir_fantasy_game_example__fantasy_game").
 */
export function modulePathToFileStem(modulePath: string): string {
  const withoutExt = modulePath.replace(/\.skir$/, "");
  if (withoutExt.startsWith("@")) {
    const normalized = withoutExt
      .slice(1)
      .replace(/-/g, "_")
      .replace(/\//g, "__");
    return `skirout__ext__${normalized}`;
  }
  const normalized = withoutExt.replace(/-/g, "_").replace(/\//g, "__");
  return `skirout_${normalized}`;
}

export function modulePathToOutputFile(modulePath: string): string {
  return `${modulePathToFileStem(modulePath)}.ml`;
}

export function modulePathToOcamlModuleName(modulePath: string): string {
  const stem = modulePathToFileStem(modulePath);
  return stem.charAt(0).toUpperCase() + stem.slice(1);
}

/**
 * Returns the internal flat identifier suffix for a record within its module,
 * e.g. "user", "user__pet", "subscription_status", "subscription_status__trial".
 */
export function getFlatRecordId(record: RecordLocation): string {
  return record.recordAncestors
    .map((r) => convertCase(r.name.text, "lower_underscore"))
    .join("__");
}

/**
 * Returns the internal top-level mutually recursive type name for a record,
 * e.g. "rec__user_", "rec__user__pet_".
 */
export function getInternalTypeName(record: RecordLocation): string {
  return `rec__${getFlatRecordId(record)}_`;
}

/**
 * Returns the OCaml submodule path within its file for a record,
 * e.g. "User", "User.Pet", "SubscriptionStatus.Trial".
 */
export function getSubmodulePath(record: RecordLocation): string {
  return record.recordAncestors
    .map((r) => convertCase(r.name.text, "UpperCamel"))
    .join(".");
}

/**
 * Returns the immediate OCaml submodule name for a record,
 * e.g. "User", "Pet", "SubscriptionStatus", "Trial".
 */
export function getImmediateSubmoduleName(record: RecordLocation): string {
  const last = record.recordAncestors.at(-1)!;
  return convertCase(last.name.text, "UpperCamel");
}

export function toStructFieldName(name: string): string {
  const candidate = convertCase(name, "lower_underscore");
  return isReservedIdentifier(candidate) || candidate === "unrecognized"
    ? `${candidate}_`
    : candidate;
}

export function toVariantCtorName(variant: Field): string {
  const candidate = convertCase(variant.name.text, "UpperCamel");
  return RESERVED_CTOR_NAMES.has(candidate) ? `${candidate}_` : candidate;
}

export function toConstantName(name: string): string {
  return `${convertCase(name, "lower_underscore")}_const`;
}

export function toMethodName(name: string): string {
  return `${convertCase(name, "lower_underscore")}_method`;
}

const RESERVED_CTOR_NAMES = new Set<string>([
  "Unknown",
  "Some",
  "None",
  "Ok",
  "Error",
  "True",
  "False",
  "Default",
  "Value",
]);

const RESERVED_IDENTIFIERS = new Set<string>([
  // OCaml keywords
  "and",
  "as",
  "assert",
  "asr",
  "begin",
  "class",
  "constraint",
  "do",
  "done",
  "downto",
  "else",
  "end",
  "exception",
  "external",
  "false",
  "for",
  "fun",
  "function",
  "functor",
  "if",
  "in",
  "include",
  "inherit",
  "initializer",
  "land",
  "lazy",
  "let",
  "lor",
  "lsl",
  "lsr",
  "lxor",
  "match",
  "method",
  "mod",
  "module",
  "mutable",
  "new",
  "nonrec",
  "object",
  "of",
  "open",
  "or",
  "private",
  "rec",
  "sig",
  "struct",
  "then",
  "to",
  "true",
  "try",
  "type",
  "val",
  "virtual",
  "when",
  "while",
  "with",
  // Built-in OCaml core types
  "bool",
  "int",
  "int32",
  "int64",
  "float",
  "string",
  "bytes",
  "char",
  "unit",
  "list",
  "array",
  "option",
  "result",
  "ref",
  "exn",
  "format",
  "lazy_t",
]);

export function isReservedIdentifier(name: string): boolean {
  return RESERVED_IDENTIFIERS.has(name);
}
