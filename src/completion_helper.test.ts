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
});
