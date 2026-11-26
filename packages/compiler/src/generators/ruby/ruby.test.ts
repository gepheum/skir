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
});
