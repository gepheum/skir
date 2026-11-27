import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { parseSkirConfig } from "../../config_parser.js";
import { ModuleSet } from "../../module_set.js";
import { GENERATOR } from "./index.js";

describe("skir-ocaml-gen", () => {
  it("is registered in config_parser", () => {
    const yamlCode = `
generators:
  - mod: skir-ocaml-gen
    outDir: ./skirout
    config: {}
`;
    const result = parseSkirConfig(yamlCode);
    expect(result).toMatch({
      skirConfig: {
        generators: [
          {
            mod: "skir-ocaml-gen",
            outDir: "./skirout",
            config: {},
          },
        ],
      },
      errors: [],
    });
  });

  it("generates OCaml code for structs, enums, methods, and constants", () => {
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
      config: {},
    };

    const output = GENERATOR.generateCode(input);
    expect(output.files.length).toBe(1);
    const file = output.files[0]!;
    expect(file.path).toBe("skirout_demo.ml");
    expect(file.code.includes("module Point = struct")).toBe(true);
    expect(file.code.includes("module Status = struct")).toBe(true);
    expect(file.code.includes("let get_status_method")).toBe(true);
    expect(file.code.includes("let origin_const")).toBe(true);
  });
});
