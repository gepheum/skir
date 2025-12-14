import type { ErrorSink, Token } from "skir-internal";

/** Registers an error if the given token does not match the expected casing. */
export function validate(
  name: Token,
  expected: "lower_underscore" | "UpperCamel" | "UPPER_UNDERSCORE",
  errors: ErrorSink,
): void {
  if (!caseMatches(name.text, expected)) {
    errors.push({
      token: name,
      expected: expected,
    });
  }
}

export function caseMatches(
  name: string,
  expected: "lower_underscore" | "UpperCamel" | "UPPER_UNDERSCORE",
): boolean {
  switch (expected) {
    case "lower_underscore":
      return /^[a-z][0-9a-z]*(_[a-z][0-9a-z]*)*$/.test(name);
    case "UpperCamel":
      return /^[A-Z][0-9A-Za-z]*$/.test(name);
    case "UPPER_UNDERSCORE":
      return /^[A-Z][0-9A-Z]*(_[A-Z][0-9A-Z]*)*$/.test(name);
  }
}
