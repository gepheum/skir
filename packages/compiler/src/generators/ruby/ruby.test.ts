import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { parseSkirConfig } from "../../config_parser.js";
import { ModuleSet } from "../../module_set.js";
import { GENERATOR } from "./index.js";

describe("skir-ruby-gen", () => {
  it("is registered in config_parser", () => {
    const yamlCode = `
generators:
  - mod: skir-ruby-gen
    outDir: ./lib/skirout
    config:
      modulePrefix: "MyApp::"
`;
    const result = parseSkirConfig(yamlCode);
    expect(result).toMatch({
      skirConfig: {
        generators: [
          {
            mod: "skir-ruby-gen",
            outDir: "./lib/skirout",
            config: {
              modulePrefix: "MyApp::",
            },
          },
        ],
      },
      errors: [],
    });
  });

  it("rejects invalid modulePrefix in config", () => {
    const yamlCode = `
generators:
  - mod: skir-ruby-gen
    outDir: ./lib/skirout
    config:
      modulePrefix: invalid_without_trailing_colons
`;
    const result = parseSkirConfig(yamlCode);
    expect(result.errors.length).toBe(1);
  });

  it("generates Ruby code for structs, enums, methods, and constants", () => {
    const moduleSet = ModuleSet.compile(
      new Map([
        [
          "demo.skir",
          `
        struct Point {
          x: int32;
          y: int32;
        }
        enum Status {
          ok;
          error: string;
        }
        method GetStatus(Point): Status = 1001;
        const ORIGIN: Point = { x: 0, y: 0 };
      `,
        ],
      ]),
      "no-cache",
      "strict",
    );
    expect(moduleSet.errors).toMatch([]);

    const modules = Array.from(moduleSet.modules.values()).map((r) => r.result);
    const input = {
      modules,
      recordMap: moduleSet.recordMap,
      config: { modulePrefix: "MyApp::" },
    };

    const output = GENERATOR.generateCode(input);
    expect(output.files.length).toBe(1);
    const file = output.files[0]!;
    expect(file.path).toBe("demo_skir.rb");
    expect(file.code.includes("# typed: strict")).toBe(true);
    expect(file.code.includes("module MyApp")).toBe(true);
    expect(file.code.includes("module Skirout")).toBe(true);
    expect(file.code.includes("module DemoSkir")).toBe(true);
    expect(file.code.includes("class Point")).toBe(true);
    expect(file.code.includes("class Status")).toBe(true);
    expect(file.code.includes("GetStatus = T.let")).toBe(true);
    expect(file.code.includes("ORIGIN = T.let")).toBe(true);
  });

  it("only generates mutable_<field> getters for non-recursive struct and array fields", () => {
    const moduleSet = ModuleSet.compile(
      new Map([
        [
          "mutable_getters.skir",
          `
        struct Child {
          x: float32;
          y: float64;
          opt_str: string?;
        }
        struct Parent {
          child: Child;
          opt_child: Child?;
          items: [int32];
          opt_items: [int32]?;
          parent: Parent?;
          score: float64;
        }
      `,
        ],
      ]),
      "no-cache",
      "strict",
    );
    expect(moduleSet.errors).toMatch([]);

    const modules = Array.from(moduleSet.modules.values()).map((r) => r.result);
    const output = GENERATOR.generateCode({
      modules,
      recordMap: moduleSet.recordMap,
      config: {},
    });
    const code = output.files[0]!.code;
    expect(code.includes("def mutable_child")).toBe(true);
    expect(code.includes("def mutable_items")).toBe(true);
    expect(code.includes("def mutable_x")).toBe(false);
    expect(code.includes("def mutable_y")).toBe(false);
    expect(code.includes("def mutable_opt_str")).toBe(false);
    expect(code.includes("def mutable_opt_child")).toBe(false);
    expect(code.includes("def mutable_opt_items")).toBe(false);
    expect(code.includes("def mutable_parent")).toBe(false);
    expect(code.includes("def mutable_score")).toBe(false);
  });

  it("escapes Ruby conversion methods and mutable_ prefix in struct field names", () => {
    const moduleSet = ModuleSet.compile(
      new Map([
        [
          "escaped_fields.skir",
          `
        struct Escaped {
          to_a: string;
          to_ary: string;
          to_h: string;
          to_str: string;
          mutable_foo: int32;
          foo: [int32];
        }
      `,
        ],
      ]),
      "no-cache",
      "strict",
    );
    expect(moduleSet.errors).toMatch([]);

    const modules = Array.from(moduleSet.modules.values()).map((r) => r.result);
    const output = GENERATOR.generateCode({
      modules,
      recordMap: moduleSet.recordMap,
      config: {},
    });
    const code = output.files[0]!.code;
    expect(code.includes("def to_a_;")).toBe(true);
    expect(code.includes("def to_ary_;")).toBe(true);
    expect(code.includes("def to_h_;")).toBe(true);
    expect(code.includes("def to_str_;")).toBe(true);
    expect(code.includes("def mutable_foo_;")).toBe(true);
    expect(code.includes("def mutable_foo;")).toBe(true);
  });
});
