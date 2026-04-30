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
    const modulePathToContent = new Map(this.modulePathToContent);
    modulePathToContent.set(this.modulePath, this.moduleContent.join("\n"));
    return provideCompletionItems(
      this.modulePath,
      this.moduleContent.join("\n"),
      this.getPosition(),
      ModuleSet.compile(modulePathToContent, "no-cache", "lenient"),
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

  it("suggests array key", () => {
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

  it("suggests array key after dot", () => {
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

  it("suggests array key in broken statement #0", () => {
    const input = new Input();
    input.moduleContent = [
      'import Triangle from "./other/module.skir";',
      "",
      "method GetFoo([Triangle|a.])",
    ];
    input.lineNumber = 2;
    input.columnNumber = 26;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 71,
      placeholderEndPos: 71,
      items: [{ name: "x" }, { name: "y" }],
    });
  });

  it("suggests array key in broken statement #1", () => {
    const input = new Input();
    input.moduleContent = [
      'import Triangle from "./other/module.skir";',
      "",
      "method GetFoo(Triangle): [Triangle|]",
    ];
    input.lineNumber = 2;
    input.columnNumber = 35;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 80,
      placeholderEndPos: 80,
      items: [{ name: "a" }, { name: "b" }, { name: "c" }],
    });
  });

  it("suggests array key in broken statement #2", () => {
    const input = new Input();
    input.moduleContent = [
      'import Triangle from "./other/module.skir";',
      "",
      "const TRIANGLES: [Triangle|a.]",
    ];
    input.lineNumber = 2;
    input.columnNumber = 29;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 74,
      placeholderEndPos: 74,
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

  it("returns null", () => {
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
    input.columnNumber = 10;
    expect(input.doProvide()).toMatch(null);
  });

  // Automatic-import completion items

  it("auto-imports when module has no import statements", () => {
    const input = new Input();
    input.modulePathToContent.set("path/to/baz.skir", "struct Foo {}");
    input.moduleContent = ["struct Holder {", "  field: Foo", "}"];
    input.lineNumber = 1;
    input.columnNumber = 12;
    // "struct Holder {" = 15 chars + newline = 16
    // "  field: " = 9 chars, so Foo starts at 25, ends at 28
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 25,
      placeholderEndPos: 28,
      items: [
        { name: "Holder" },
        {
          name: "Foo",
          modulePath: "path/to/baz.skir",
          importBlockEdit: {
            oldStart: 0,
            oldEnd: 0,
            newText: 'import { Foo } from "path/to/baz.skir";\n\n',
          },
        },
      ],
    });
  });

  it("auto-imports when the other module is already imported under an alias", () => {
    const input = new Input();
    input.modulePathToContent.set("path/to/baz.skir", "struct Foo {}");
    input.moduleContent = [
      'import * as baz from "./baz.skir";',
      "",
      "struct Holder {",
      "  field: Foo",
      "}",
    ];
    input.lineNumber = 3;
    input.columnNumber = 12;
    // Line 0: 34 chars + newline = 35
    // Line 1: empty + newline = 1
    // Line 2: "struct Holder {" = 15 + newline = 16
    // "  field: " = 9 chars, so Foo starts at 61, ends at 64
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 61,
      placeholderEndPos: 64,
      items: [
        { name: "baz" },
        { name: "Holder" },
        {
          name: "Foo",
          modulePath: "path/to/baz.skir",
          insertText: "baz.Foo",
          importBlockEdit: undefined,
        },
      ],
    });
  });

  it("auto-imports when the other module imports some names but not Foo", () => {
    const input = new Input();
    input.modulePathToContent.set(
      "path/to/baz.skir",
      "struct Foo {}\nstruct Bar {}",
    );
    input.moduleContent = [
      'import { Bar } from "./baz.skir";',
      "",
      "struct Holder {",
      "  field: Foo",
      "}",
    ];
    input.lineNumber = 3;
    input.columnNumber = 12;
    // Line 0: "import { Bar } from "./baz.skir";" = 33 chars + newline = 34
    // Line 1: empty + newline = 1
    // Line 2: "struct Holder {" = 15 + newline = 16
    // "  field: " = 9 chars, so Foo starts at 60, ends at 63
    // "import { Bar } from "./baz.skir";" is 33 chars, so importBlockRange end is 33.
    const bazImportBlockEnd = 33;
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 60,
      placeholderEndPos: 63,
      items: [
        { name: "Bar" },
        { name: "Holder" },
        {
          name: "Foo",
          modulePath: "path/to/baz.skir",
          importBlockEdit: {
            oldStart: 0,
            oldEnd: bazImportBlockEnd,
            newText: 'import {\n  Bar,\n  Foo,\n} from "path/to/baz.skir";',
          },
        },
      ],
    });
  });

  it("auto-imports when module has imports but none for the other module", () => {
    const input = new Input();
    input.modulePathToContent.set("path/to/baz.skir", "struct Foo {}");
    input.moduleContent = [
      'import * as other from "./other/module.skir";',
      "",
      "struct Holder {",
      "  field: Foo",
      "}",
    ];
    input.lineNumber = 3;
    input.columnNumber = 12;
    // Line 0: "import * as other from "./other/module.skir";" = 45 chars + newline = 46
    // Line 1: empty + newline = 1
    // Line 2: "struct Holder {" = 15 + newline = 16
    // "  field: " = 9 chars, so Foo starts at 72, ends at 75
    expect(input.doProvide()).toMatch({
      placeholderStartPos: 72,
      placeholderEndPos: 75,
      items: [
        { name: "other" },
        { name: "Holder" },
        {
          name: "Foo",
          modulePath: "path/to/baz.skir",
          importBlockEdit: {
            oldStart: 0,
            oldEnd: 45,
            newText:
              'import { Foo } from "path/to/baz.skir";\nimport * as other from "path/to/other/module.skir";',
          },
        },
      ],
    });
  });
});
