import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { parseSkirConfig } from "../../config_parser.js";
import { ModuleSet } from "../../module_set.js";
import { GENERATOR } from "./index.js";

describe("skir-scala-gen", () => {
  it("is registered in config_parser", () => {
    const yamlCode = `
generators:
  - mod: skir-scala-gen
    outDir: ./src/main/scala/skirout
    config:
      packagePrefix: my.project.
`;
    const result = parseSkirConfig(yamlCode);
    expect(result).toMatch({
      skirConfig: {
        generators: [
          {
            mod: "skir-scala-gen",
            outDir: "./src/main/scala/skirout",
            config: {
              packagePrefix: "my.project.",
            },
          },
        ],
      },
      errors: [],
    });
  });

  it("rejects invalid packagePrefix in config", () => {
    const yamlCode = `
generators:
  - mod: skir-scala-gen
    outDir: ./src/main/scala/skirout
    config:
      packagePrefix: invalid_without_trailing_dot
`;
    const result = parseSkirConfig(yamlCode);
    expect(result.errors.length).toBe(1);
  });

  it("generates Scala code and symbols for structs, enums, methods, and constants", () => {
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
      config: { packagePrefix: "com.example." },
    };

    const output = GENERATOR.generateCode(input);
    expect(output.files.length).toBe(1);
    const file = output.files[0]!;
    expect(file.path).toBe("demo.scala");
    expect(file.code.includes("package com.example.skirout.demo")).toBe(true);
    expect(file.code.includes("final class Point")).toBe(true);
    expect(file.code.includes("sealed abstract class Status")).toBe(true);
    expect(file.code.includes("lazy val GetStatus")).toBe(true);
    expect(file.code.includes("lazy val ORIGIN")).toBe(true);

    const symbols = GENERATOR.symbols(input);
    const demoModule = modules[0]!;
    const pointLoc = demoModule.records.find(
      (r) => r.record.name.text === "Point",
    )!;
    const statusLoc = demoModule.records.find(
      (r) => r.record.name.text === "Status",
    )!;
    expect(symbols.record(pointLoc).reference).toBe(
      "_root_.com.example.skirout.demo.Point",
    );
    expect(symbols.method(demoModule, demoModule.methods[0]!).reference).toBe(
      "_root_.com.example.skirout.demo.GetStatus",
    );
    const okVariant = statusLoc.record.fields[0]!;
    const errorVariant = statusLoc.record.fields[1]!;
    expect(symbols.variant(statusLoc, okVariant).reference).toBe(
      "_root_.com.example.skirout.demo.Status.Kind.OK_CONST",
    );
    expect(symbols.variantConstructor(statusLoc, okVariant).reference).toBe(
      "_root_.com.example.skirout.demo.Status.OK",
    );
    expect(symbols.variantConstructor(statusLoc, errorVariant).reference).toBe(
      "_root_.com.example.skirout.demo.Status.ErrorWrapper({value})",
    );
    expect(symbols.variantValue(statusLoc, errorVariant).reference).toBe(
      "({value}.asInstanceOf[_root_.com.example.skirout.demo.Status.ErrorWrapper]).value",
    );
  });
});
