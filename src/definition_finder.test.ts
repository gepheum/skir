import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { findDefinition, findReferences } from "./definition_finder.js";
import { ModuleSet } from "./module_set.js";

const pathToCode = new Map<string, string>();

// line 0:  (empty)
// line 1:  import * as other_module from "./other/module";
// line 2:  (empty)
// line 3:  struct Outer {
// line 4:    struct Foo {}
// line 5:  }
// line 6:  (empty)
// line 7:  struct Bar {
// line 8:    foo: Outer.Foo;
// line 9:    foo2: .Outer.Foo;
// line 10: (empty)
// line 11:   struct Inner {}
// line 12:   inner: Inner;
// line 13:   zoo: other_module.Outer.Zoo;
// line 14: }
// line 15: (empty)
// line 16: method GetBar(Outer.Foo): Bar = 101;
// line 17: method GetBar2(Outer.Foo): Bar = 100;
// line 18: (empty)
// line 19: const FOO: Outer.Foo = {};
pathToCode.set(
  "path/to/module",
  [
    "",
    'import * as other_module from "./other/module";',
    "",
    "struct Outer {",
    "  struct Foo {}",
    "}",
    "",
    "struct Bar {",
    "  foo: Outer.Foo;",
    "  foo2: .Outer.Foo;",
    "",
    "  struct Inner {}",
    "  inner: Inner;",
    "  zoo: other_module.Outer.Zoo;",
    "}",
    "",
    "method GetBar(Outer.Foo): Bar = 101;",
    "method GetBar2(Outer.Foo): Bar = 100;",
    "",
    "const FOO: Outer.Foo = {};",
    "",
  ].join("\n"),
);
pathToCode.set(
  "path/to/other/module",
  ["", "struct Outer {", "  struct Zoo {}", "}", ""].join("\n"),
);
pathToCode.set(
  "path/to/keyed-array-module",
  [
    "",
    "struct Foo {",
    "  struct Bar {",
    "    id: int32;",
    "  }",
    "  bar: Bar;",
    "}",
    "",
    "struct Zoo {",
    "  foos: [Foo|bar.id];",
    "}",
    "",
  ].join("\n"),
);
pathToCode.set(
  "path/to/constant-value-module",
  [
    "",
    "struct Foo {",
    "  enum Bar {",
    "    zoo: int32;",
    "  }",
    "  foo: int32;",
    "  bar: Bar;",
    "}",
    "",
    "const FOOS: [Foo] = [",
    "  {",
    "    foo: 10,",
    "    bar: {",
    '      kind: "zoo",',
    "      value: 10,",
    "    },",
    "  },",
    "];",
    "",
  ].join("\n"),
);
pathToCode.set(
  "path/to/doc-comment-module",
  [
    "",
    "struct Foobar {",
    "  /// [bar]",
    "  foo: int32;",
    "  /// [Foobar.foo]",
    "  bar: int32;",
    "}",
    "",
  ].join("\n"),
);
const moduleSet = ModuleSet.compile(pathToCode);

interface Range {
  modulePath: string;
  lineNumber: number;
  colNumberStart: number;
  colNumberEnd: number;
}

describe("definition finder", () => {
  const module = moduleSet.modules.get("path/to/module")!.result;
  const keyedArrayModule = moduleSet.modules.get(
    "path/to/keyed-array-module",
  )!.result;
  const constantValueModule = moduleSet.modules.get(
    "path/to/constant-value-module",
  )!.result;
  const docCommentModule = moduleSet.modules.get(
    "path/to/doc-comment-module",
  )!.result;

  // Converts a (modulePath, lineNumber, colNumber) triple to a flat character
  // position in the source string, so tests can be written in terms of
  // human-readable line/column numbers instead of opaque offsets.
  function positionOf(
    modulePath: string,
    lineNumber: number,
    colNumber: number,
  ): number {
    const source = pathToCode.get(modulePath)!;
    let pos = 0;
    for (let i = 0; i < lineNumber; i++) {
      pos = source.indexOf("\n", pos) + 1;
    }
    return pos + colNumber;
  }

  // Verifies that:
  //  1. findReferences(definition) returns exactly the expected reference ranges.
  //  2. findDefinition at both the start and end column of every reference
  //     resolves back to the definition range.
  function checkDefinitionAndReferences(
    definition: Range,
    references: readonly Range[],
  ): void {
    const allModules = [
      module,
      keyedArrayModule,
      constantValueModule,
      docCommentModule,
    ];

    // Get the declaration token by navigating from the first reference.
    // findDefinition at a usage site returns the declaration.
    if (references.length === 0) {
      throw new Error(
        "checkDefinitionAndReferences requires at least one reference",
      );
    }
    const firstRef = references[0]!;
    const firstRefMod = moduleSet.modules.get(firstRef.modulePath)!.result;
    const firstRefPos = positionOf(
      firstRef.modulePath,
      firstRef.lineNumber,
      firstRef.colNumberStart,
    );
    const firstMatch = findDefinition(firstRefMod, firstRefPos);
    if (!firstMatch?.declaration) {
      throw new Error(
        `Could not find declaration via reference ` +
          `(${firstRef.modulePath}:${firstRef.lineNumber}:${firstRef.colNumberStart})`,
      );
    }
    const defToken = firstMatch.declaration.name;

    // 1. findReferences should return exactly the expected ranges (by position).
    const refs = findReferences(defToken, allModules);
    const expectedPositions = references.map((r) =>
      positionOf(r.modulePath, r.lineNumber, r.colNumberStart),
    );
    expect(refs).toMatch(expectedPositions.map((p) => ({ position: p })));

    // 2. findDefinition at each reference's start AND end col resolves back to
    //    the definition, and exposes the hovered token with its start position.
    for (const ref of references) {
      const refMod = moduleSet.modules.get(ref.modulePath)!.result;
      const refStartPos = positionOf(
        ref.modulePath,
        ref.lineNumber,
        ref.colNumberStart,
      );
      for (const col of [ref.colNumberStart, ref.colNumberEnd]) {
        const refPos = positionOf(ref.modulePath, ref.lineNumber, col);
        const match = findDefinition(refMod, refPos);
        expect(match).toMatch({
          modulePath: definition.modulePath,
          declaration: { name: { position: defToken.position } },
          referenceToken: { position: refStartPos },
        });
      }
    }
  }

  it("resolves a module path import to the target module", () => {
    // The '"./other/module"' string token starts at line 1 col 30 (the opening
    // quote) of the main module.
    const tokenPos = positionOf("path/to/module", 1, 30);
    expect(findDefinition(module, tokenPos)).toMatch({
      modulePath: "path/to/other/module",
      declaration: undefined,
      referenceToken: { position: tokenPos },
    });
  });

  it("resolves the name token of a declaration to itself", () => {
    // "Bar" struct name is on line 7 col 7 of the main module.
    const barPosition = positionOf("path/to/module", 7, 7);
    expect(findDefinition(module, barPosition)).toMatch({
      modulePath: "path/to/module",
      declaration: { name: { position: barPosition } },
      referenceToken: { position: barPosition },
    });
  });

  describe("record types", () => {
    it("Foo is referenced in field types, method types and constant type", () => {
      checkDefinitionAndReferences(
        // "Foo" struct name on line 4 col 9
        {
          modulePath: "path/to/module",
          lineNumber: 4,
          colNumberStart: 9,
          colNumberEnd: 11,
        },
        [
          // foo: Outer.Foo  (field, line 8)
          {
            modulePath: "path/to/module",
            lineNumber: 8,
            colNumberStart: 13,
            colNumberEnd: 15,
          },
          // foo2: .Outer.Foo  (field, line 9)
          {
            modulePath: "path/to/module",
            lineNumber: 9,
            colNumberStart: 15,
            colNumberEnd: 17,
          },
          // method GetBar(Outer.Foo): Bar  (request type, line 16)
          {
            modulePath: "path/to/module",
            lineNumber: 16,
            colNumberStart: 20,
            colNumberEnd: 22,
          },
          // method GetBar2(Outer.Foo): Bar  (request type, line 17)
          {
            modulePath: "path/to/module",
            lineNumber: 17,
            colNumberStart: 21,
            colNumberEnd: 23,
          },
          // const FOO: Outer.Foo  (constant type, line 19)
          {
            modulePath: "path/to/module",
            lineNumber: 19,
            colNumberStart: 17,
            colNumberEnd: 19,
          },
        ],
      );
    });

    it("Bar is referenced in method response types", () => {
      checkDefinitionAndReferences(
        // "Bar" struct name on line 7 col 7
        {
          modulePath: "path/to/module",
          lineNumber: 7,
          colNumberStart: 7,
          colNumberEnd: 9,
        },
        [
          // method GetBar(...): Bar  (line 16)
          {
            modulePath: "path/to/module",
            lineNumber: 16,
            colNumberStart: 26,
            colNumberEnd: 28,
          },
          // method GetBar2(...): Bar  (line 17)
          {
            modulePath: "path/to/module",
            lineNumber: 17,
            colNumberStart: 27,
            colNumberEnd: 29,
          },
        ],
      );
    });

    it("Inner is referenced in a field type", () => {
      checkDefinitionAndReferences(
        // "Inner" struct name on line 11 col 9
        {
          modulePath: "path/to/module",
          lineNumber: 11,
          colNumberStart: 9,
          colNumberEnd: 13,
        },
        [
          // inner: Inner  (line 12)
          {
            modulePath: "path/to/module",
            lineNumber: 12,
            colNumberStart: 9,
            colNumberEnd: 13,
          },
        ],
      );
    });

    it("returns empty references for an unused symbol", () => {
      const decl = module.nameToDeclaration["GetBar2"];
      if (decl.kind !== "method") throw new Error("GetBar2 not found");
      const refs = findReferences(decl.name, [
        module,
        keyedArrayModule,
        constantValueModule,
        docCommentModule,
      ]);
      expect(refs).toMatch([]);
    });
  });

  describe("keyed array key path", () => {
    it("bar field is referenced in the array key path", () => {
      checkDefinitionAndReferences(
        // "bar" field on line 5 col 2
        {
          modulePath: "path/to/keyed-array-module",
          lineNumber: 5,
          colNumberStart: 2,
          colNumberEnd: 4,
        },
        [
          // [Foo|bar.id]  — "bar" token on line 9 col 13
          {
            modulePath: "path/to/keyed-array-module",
            lineNumber: 9,
            colNumberStart: 13,
            colNumberEnd: 15,
          },
        ],
      );
    });

    it("id field is referenced in the array key path", () => {
      checkDefinitionAndReferences(
        // "id" field on line 3 col 4
        {
          modulePath: "path/to/keyed-array-module",
          lineNumber: 3,
          colNumberStart: 4,
          colNumberEnd: 5,
        },
        [
          // [Foo|bar.id]  — "id" token on line 9 col 17
          {
            modulePath: "path/to/keyed-array-module",
            lineNumber: 9,
            colNumberStart: 17,
            colNumberEnd: 18,
          },
        ],
      );
    });
  });

  describe("constant values", () => {
    it("foo field is referenced as a struct value key", () => {
      checkDefinitionAndReferences(
        // "foo" field on line 5 col 2
        {
          modulePath: "path/to/constant-value-module",
          lineNumber: 5,
          colNumberStart: 2,
          colNumberEnd: 4,
        },
        [
          // { foo: 10, ... }  — "foo" key on line 11 col 4
          {
            modulePath: "path/to/constant-value-module",
            lineNumber: 11,
            colNumberStart: 4,
            colNumberEnd: 6,
          },
        ],
      );
    });

    it("zoo enum variant is referenced as a kind literal in a constant value", () => {
      checkDefinitionAndReferences(
        // "zoo" field on line 3 col 4
        {
          modulePath: "path/to/constant-value-module",
          lineNumber: 3,
          colNumberStart: 4,
          colNumberEnd: 6,
        },
        [
          // kind: "zoo"  — the "zoo" string token on line 13 col 12
          {
            modulePath: "path/to/constant-value-module",
            lineNumber: 13,
            colNumberStart: 12,
            colNumberEnd: 16,
          },
        ],
      );
    });
  });

  describe("doc comments", () => {
    it("Foobar struct is referenced in a doc comment", () => {
      checkDefinitionAndReferences(
        // "Foobar" struct name on line 1 col 7
        {
          modulePath: "path/to/doc-comment-module",
          lineNumber: 1,
          colNumberStart: 7,
          colNumberEnd: 12,
        },
        [
          // /// [Foobar.foo]  — "Foobar" token on line 4 col 7
          {
            modulePath: "path/to/doc-comment-module",
            lineNumber: 4,
            colNumberStart: 7,
            colNumberEnd: 12,
          },
        ],
      );
    });

    it("foo field is referenced in a doc comment", () => {
      checkDefinitionAndReferences(
        // "foo" field on line 3 col 2
        {
          modulePath: "path/to/doc-comment-module",
          lineNumber: 3,
          colNumberStart: 2,
          colNumberEnd: 4,
        },
        [
          // /// [Foobar.foo]  — "foo" token on line 4 col 14
          {
            modulePath: "path/to/doc-comment-module",
            lineNumber: 4,
            colNumberStart: 14,
            colNumberEnd: 16,
          },
        ],
      );
    });

    it("bar field is referenced in a doc comment", () => {
      checkDefinitionAndReferences(
        // "bar" field on line 5 col 2
        {
          modulePath: "path/to/doc-comment-module",
          lineNumber: 5,
          colNumberStart: 2,
          colNumberEnd: 4,
        },
        [
          // /// [bar]  — "bar" token on line 2 col 7
          {
            modulePath: "path/to/doc-comment-module",
            lineNumber: 2,
            colNumberStart: 7,
            colNumberEnd: 9,
          },
        ],
      );
    });
  });
});
