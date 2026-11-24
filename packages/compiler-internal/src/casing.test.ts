import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { capitalize, convertCase } from "./casing.js";

describe("casing", () => {
  it("convert", () => {
    expect(convertCase("FOO_BAR", "UPPER_UNDERSCORE")).toBe("FOO_BAR");
    expect(convertCase("FOO_BAR", "UpperCamel")).toBe("FooBar");
    expect(convertCase("FOO_BAR", "lowerCamel")).toBe("fooBar");
    expect(convertCase("OK", "lower_underscore")).toBe("ok");
    expect(convertCase("F", "lower_underscore")).toBe("f");
    expect(convertCase("F0", "lower_underscore")).toBe("f0");
    expect(convertCase("F0", "UpperCamel")).toBe("F0");
    expect(convertCase("foo", "UpperCamel")).toBe("Foo");
    expect(convertCase("fo0", "UpperCamel")).toBe("Fo0");
    expect(convertCase("FOO_BAR", "lower_underscore")).toBe("foo_bar");
    expect(convertCase("FooBar", "UPPER_UNDERSCORE")).toBe("FOO_BAR");
    expect(convertCase("fooBar", "UPPER_UNDERSCORE")).toBe("FOO_BAR");
    expect(convertCase("foo_bar", "UPPER_UNDERSCORE")).toBe("FOO_BAR");
    expect(convertCase("fo6_b7r", "UpperCamel")).toBe("Fo6B7r");
  });

  it("capitalize", () => {
    expect(capitalize("fooBar")).toBe("FooBar");
  });
});
