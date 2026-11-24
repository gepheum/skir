import type { Casing } from "./types.js";

export function convertCase(text: string, target: Casing): string {
  let words: readonly string[];
  if (text.includes("_") || !/[a-z]/.test(text)) {
    words = text.split("_").map((w) => w.toLowerCase());
  } else {
    words = text.split(/(?=[A-Z])/).map((w) => w.toLowerCase());
  }
  switch (target) {
    case "lowerCamel":
      return words.map((w, i) => (i ? capitalize(w) : w)).join("");
    case "lower_underscore":
      return words.join("_");
    case "UpperCamel":
      return words.map(capitalize).join("");
    case "UPPER_UNDERSCORE":
      return words.map((w) => w.toUpperCase()).join("_");
  }
}

/** Returns a new string with the first letter of `name` capitalized. */
export function capitalize(name: string): string {
  return name[0]!.toUpperCase() + name.slice(1);
}
