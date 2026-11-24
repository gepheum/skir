import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { simpleHash } from "./simple_hash.js";

describe("simple hash", () => {
  it("works", () => {
    expect(simpleHash("")).toBe(0);
    expect(simpleHash("hello")).toBe(99162322);
    expect(simpleHash("world")).toBe(113318802);
  });
});
