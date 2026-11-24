import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { unquoteAndUnescape } from "./literals.js";

describe("literals", () => {
  it("#unquoteAndUnescape() works", () => {
    expect(unquoteAndUnescape('"foo\\\r\n\\\n\\\r\\tbar\\\\t"')).toBe(
      ["foo", "", "", "\tbar\\t"].join("\n"),
    );
  });
});
