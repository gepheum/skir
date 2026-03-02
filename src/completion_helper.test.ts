import { expect } from "buckwheat";
import { describe, it } from "mocha";
import {
  CompletionItems,
  provideCompletionItems,
} from "./completion_helper.js";
import { ModuleSet } from "./module_set.js";

class Input {
  modulePath = "path/to/module.skir";
  moduleContent: string[] = [];
  lineNumber = 0;
  columnNumber = 0;
  modulePathToContent = new Map<string, string>();

  constructor() {
    this.modulePathToContent.set(
      "path/to/other/module.skir",
      `
      struct Triangle {
        struct Point {
          x: float32;
          y: float32;
        }

        a: Point;
        b: Point;
        c: Point;
      }`,
    );
    this.modulePathToContent.set("path/to/foo.skir", "");
    this.modulePathToContent.set("path/to_bar.skir", "");
  }

  doProvide(): CompletionItems | null {
    return provideCompletionItems(
      this.modulePath,
      this.moduleContent.join("\n"),
      this.getPosition(),
      ModuleSet.compile(this.modulePathToContent),
    );
  }

  private getPosition(): number {
    const lines = this.moduleContent;
    let position = 0;
    for (let i = 0; i < this.lineNumber; i++) {
      position += lines[i]!.length + 1; // +1 for the "\n" separator
    }
    return position + this.columnNumber;
  }
}

describe("completion_helper", () => {
  it("suggests top-level types and aliases", () => {
    const input = new Input();
    input.moduleContent = [
      'import * as other from "./other/module.skir";',
      "",
      "struct TriangleHolder {",
      "  triangle: ",
      "}",
      "",
      "struct Foo {}",
    ];
    input.lineNumber = 3;
    input.columnNumber = 11;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 82,
      placeholderEndPos: 82,
      items: [{ name: "other" }, { name: "TriangleHolder" }, { name: "Foo" }],
    });
  });

  it("suggests types in alias", () => {
    const input = new Input();
    input.moduleContent = [
      'import * as other from "./other/module.skir";',
      "",
      "struct TriangleHolder {",
      "  triangle: other.",
      "}",
    ];
    input.lineNumber = 3;
    input.columnNumber = 18;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 89,
      placeholderEndPos: 89,
      items: [{ name: "Triangle" }],
    });
  });

  it("suggests nested types", () => {
    const input = new Input();
    input.moduleContent = [
      'import * as other from "./other/module.skir";',
      "",
      "struct PointHolder {",
      "  point: other.Triangle.",
      "}",
    ];
    input.lineNumber = 3;
    input.columnNumber = 24;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 92,
      placeholderEndPos: 92,
      items: [{ name: "Point" }],
    });
  });

  it("suggests types on valid identifier", () => {
    const input = new Input();
    input.moduleContent = [
      'import * as other from "./other/module.skir";',
      "",
      "struct TriangleHolder {",
      "  triangle: other.foo",
      "}",
    ];
    input.lineNumber = 3;
    input.columnNumber = 18;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 89,
      placeholderEndPos: 92,
      items: [{ name: "Triangle" }],
    });

    // Move to the end of "foo"
    input.columnNumber = 21;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 89,
      placeholderEndPos: 92,
      items: [{ name: "Triangle" }],
    });
  });

  it("suggests types on broken method request", () => {
    const input = new Input();
    input.moduleContent = [
      'import Triangle from "./other/module.skir";',
      "",
      "method GetFoo()",
      "struct Foo {}",
    ];
    input.lineNumber = 2;
    input.columnNumber = 14;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 59,
      placeholderEndPos: 59,
      items: [{ name: "Triangle" }, { name: "Foo" }],
    });
  });

  it("suggests types on broken method response", () => {
    const input = new Input();
    input.moduleContent = [
      'import Triangle from "./other/module.skir";',
      "",
      "method GetFoo(string): ",
    ];
    input.lineNumber = 2;
    input.columnNumber = 23;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 68,
      placeholderEndPos: 68,
      items: [{ name: "Triangle" }],
    });
  });

  it("suggests types on broken constant", () => {
    const input = new Input();
    input.moduleContent = [
      'import Triangle from "./other/module.skir";',
      "",
      "const TRIANGLE: ",
    ];
    input.lineNumber = 2;
    input.columnNumber = 16;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 61,
      placeholderEndPos: 61,
      items: [{ name: "Triangle" }],
    });
  });

  it("suggests array keys", () => {
    const input = new Input();
    input.moduleContent = [
      'import Triangle from "./other/module.skir";',
      "",
      "method GetFoo([Triangle|]): string = 100;",
    ];
    input.lineNumber = 2;
    input.columnNumber = 24;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 69,
      placeholderEndPos: 69,
      items: [{ name: "a" }, { name: "b" }, { name: "c" }],
    });
  });

  it("suggests array keys after dot", () => {
    const input = new Input();
    input.moduleContent = [
      'import Triangle from "./other/module.skir";',
      "",
      "method GetFoo([Triangle|a.]): string = 100;",
    ];
    input.lineNumber = 2;
    input.columnNumber = 26;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 71,
      placeholderEndPos: 71,
      items: [{ name: "x" }, { name: "y" }],
    });
  });

  it("suggests struct fields in constant", () => {
    const input = new Input();
    input.moduleContent = [
      'import Triangle from "./other/module.skir";',
      "",
      "const TRIANGLE: Triangle = { a: {x: 10, } }",
    ];
    input.lineNumber = 2;
    input.columnNumber = 40;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 85,
      placeholderEndPos: 85,
      items: [{ name: "y" }],
    });
  });

  it("suggests enum constant variant name", () => {
    const input = new Input();
    input.moduleContent = [
      "enum Status {",
      "  OK;",
      "  error: string;",
      "}",
      "",
      "const STATUS: Status = ''",
    ];
    input.lineNumber = 5;
    input.columnNumber = 24;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 64,
      placeholderEndPos: 64,
      items: [{ name: "UNKNOWN" }, { name: "OK" }],
    });
  });

  it("suggests enum constant variant name at end of string", () => {
    const input = new Input();
    input.moduleContent = [
      "enum Status {",
      "  OK;",
      "  error: string;",
      "}",
      "",
      "const STATUS: Status = 'foo'",
    ];
    input.lineNumber = 5;
    input.columnNumber = 27;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 64,
      placeholderEndPos: 67,
      items: [{ name: "UNKNOWN" }, { name: "OK" }],
    });
  });

  it("suggests enum wrapper variant name", () => {
    const input = new Input();
    input.moduleContent = [
      "enum Status {",
      "  OK;",
      "  error: string;",
      "}",
      "",
      "const STATUS: Status = {kind: ''}",
    ];
    input.lineNumber = 5;
    input.columnNumber = 31;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 71,
      placeholderEndPos: 71,
      items: [{ name: "error" }],
    });
  });

  it("suggests value field on enum variant", () => {
    const input = new Input();
    input.moduleContent = [
      "enum Status {",
      "  OK;",
      "  error: string;",
      "}",
      "",
      "const STATUS: Status = {kind: 'error', }",
    ];
    input.lineNumber = 5;
    input.columnNumber = 39;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 79,
      placeholderEndPos: 79,
      items: [{ name: "value" }],
    });
  });

  it("suggests kind field on enum variant", () => {
    const input = new Input();
    input.moduleContent = [
      "enum Status {",
      "  OK;",
      "  error: string;",
      "}",
      "",
      "const STATUS: Status = {value: {}, }",
    ];
    input.lineNumber = 5;
    input.columnNumber = 35;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 75,
      placeholderEndPos: 75,
      items: [{ name: "kind" }],
    });
  });

  it("suggests 'kind' after path to enum #0", () => {
    const input = new Input();
    input.moduleContent = [
      "enum Status {",
      "  OK;",
      "  error: string;",
      "}",
      "",
      "const STATUSES: [Status|] = [];",
    ];
    input.lineNumber = 5;
    input.columnNumber = 24;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 64,
      placeholderEndPos: 64,
      items: [{ name: "kind" }],
    });
  });

  it("suggests 'kind' after path to enum #1", () => {
    const input = new Input();
    input.moduleContent = [
      "enum Status {",
      "  OK;",
      "  error: string;",
      "}",
      "struct Foo { status: Status; }",
      "",
      "const FOOS: [Foo|status.] = [];",
    ];
    input.lineNumber = 6;
    input.columnNumber = 24;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 95,
      placeholderEndPos: 95,
      items: [{ name: "kind" }],
    });
  });

  it("suggests module paths #0", () => {
    const input = new Input();
    input.moduleContent = ["import * as foo from '';"];
    input.lineNumber = 0;
    input.columnNumber = 22;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 22,
      placeholderEndPos: 22,
      items: [{ name: "path/" }],
    });
  });

  it("suggests module paths #1", () => {
    const input = new Input();
    input.moduleContent = ["import * as foo from 'path';"];
    input.lineNumber = 0;
    input.columnNumber = 26;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 22,
      placeholderEndPos: 26,
      items: [{ name: "path/" }],
    });
  });

  it("suggests module paths #2", () => {
    const input = new Input();
    input.moduleContent = ["import * as foo from 'path/';"];
    input.lineNumber = 0;
    input.columnNumber = 27;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 22,
      placeholderEndPos: 27,
      items: [{ name: "path/to/" }, { name: "path/to_bar.skir" }],
    });
  });

  it("suggests module paths #3", () => {
    const input = new Input();
    input.moduleContent = ["import * as foo from 'path/to/';"];
    input.lineNumber = 0;
    input.columnNumber = 27;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 22,
      placeholderEndPos: 30,
      items: [{ name: "path/to/other/" }, { name: "path/to/foo.skir" }],
    });
  });

  it("suggests module paths #4", () => {
    const input = new Input();
    input.moduleContent = ["import * as foo from './';"];
    input.lineNumber = 0;
    input.columnNumber = 24;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 22,
      placeholderEndPos: 24,
      items: [{ name: "./other/" }, { name: "./foo.skir" }],
    });
  });

  it("suggests module paths #5", () => {
    const input = new Input();
    input.moduleContent = ["import * as foo from '../';"];
    input.lineNumber = 0;
    input.columnNumber = 25;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 22,
      placeholderEndPos: 25,
      items: [{ name: "../to_bar.skir" }],
    });
  });
});
