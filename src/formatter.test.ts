import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { formatModule, FormattedModule } from "./formatter.js";
import { parseModule } from "./parser.js";
import { tokenizeModule } from "./tokenizer.js";

/**
 * Like `formatModule`, but additionally asserts that the formatted output can
 * be tokenized and parsed in strict mode without any errors.  Use this helper
 * in every new test so that a formatter bug producing syntactically invalid
 * output is caught immediately.
 */
function formatModuleAndCheck(
  sourceCode: string,
  modulePath: string,
  randomGenerator?: () => number,
): FormattedModule {
  const formatted = formatModule(sourceCode, modulePath, randomGenerator);
  if (formatted.errors.length === 0) {
    const tokens = tokenizeModule(formatted.newSourceCode, modulePath);
    if (tokens.errors.length > 0) {
      throw new Error(
        `Formatted output failed to tokenize: ${tokens.errors.map((e) => e.message).join(", ")}\n\nFormatted source:\n${formatted.newSourceCode}`,
      );
    }
    const parsed = parseModule(tokens.result, "strict");
    if (parsed.errors.length > 0) {
      throw new Error(
        `Formatted output failed to parse: ${parsed.errors.map((e) => e.message).join(", ")}\n\nFormatted source:\n${formatted.newSourceCode}`,
      );
    }
  }
  return formatted;
}

const UNFORMATTED_MODULE = `//module
import A from 'module.skir';  import * as foo from 'other_module.skir';
import  c,a,b  from  './path/to/other_module.skir';



import {Foo} from "@gepheum/foo.skir";
  struct Empty1 { }
struct Empty2 { //
  }  //

struct S1 {
  a: int32;
  c: double?;

//
//a
// b
///a
/// b
///
b: string;
removed;
    enum E {


    }
}

// doc for
  /* foo
  */
// s2
struct S2 {
  a : int32=0 ;
  b : string=1;//
  c:[[x|foo.a.kind]?] ?=2;
  removed 3, 4..12, 13;
/*
*
*/
/// foo
  struct Nested {
}
}

enum E1 {
  A;
  B;
  c: bool;
}
enum E2 {
  A=1;
  B=2;
}

method M(Request):Response = 123;

const CONST: [Type] = [
  1, [], {}, {
    a : true,
    b: null,
    c: 'n\\\\"',
    d: 'n\\"',
// c doc
      e: [ ]  //c
  },
  {||}, {|  
    a: true,
    b://
3.14
,
  |},
[
'fo',"fo'",
"fo\\"",
'fo"',
'fo\\"',
'fo\\\\"',
]

];

const F: Foo? = {
  a: null,b: 3.14,c:false
}

;struct S {
  // a
}

struct So ( 100 ) { // a
  // b
    }  // d

// a

  // c

//d

method GetFoo(struct {a: enum { z: int32; g
:
bool;
h: //
[
int32 //
?];}; b: bool; }): struct {
  x: int32; y: int32;} = 123;

  struct G {
  // a

  // b
  // b2


  // c


  struct WithQuestionMarkStableIdentifier( ? ) {}
}

  method WithQuestionMarkStableIdentifier(bool):bool = /**/ ?;`;

const EXPECTED_FORMATTED_MODULE = [
  "// module",
  "",
  'import { Foo } from "@gepheum/foo.skir";',
  "",
  'import { A } from "module.skir";',
  'import * as foo from "other_module.skir";',
  "import {",
  "  a,",
  "  b,",
  "  c,",
  '} from "path/to/path/to/other_module.skir";',
  "",
  "struct Empty1 {}",
  "struct Empty2 {  //",
  "}  //",
  "",
  "struct S1 {",
  "  a: int32;",
  "  c: double?;",
  "",
  "  //",
  "  // a",
  "  // b",
  "  /// a",
  "  /// b",
  "  ///",
  "  b: string;",
  "  removed;",
  "  enum E {}",
  "}",
  "",
  "// doc for",
  "/* foo",
  "  */",
  "// s2",
  "struct S2 {",
  "  a: int32 = 0;",
  "  b: string = 1;  //",
  "  c: [[x|foo.a.kind]?]? = 2;",
  "  removed 3, 4..12, 13;",
  "  /*",
  "*",
  "*/",
  "  /// foo",
  "  struct Nested {}",
  "}",
  "",
  "enum E1 {",
  "  A;",
  "  B;",
  "  c: bool;",
  "}",
  "enum E2 {",
  "  A = 1;",
  "  B = 2;",
  "}",
  "",
  "method M(",
  "  Request",
  "): Response = 123;",
  "",
  "const CONST: [Type] = [",
  "  1,",
  "  [],",
  "  {},",
  "  {",
  "    a: true,",
  "    b: null,",
  "    c: 'n\\\\\"',",
  "    d: 'n\\\"',",
  "    // c doc",
  "    e: [],  // c,",
  "  },",
  "  {||},",
  "  {|",
  "    a: true,",
  "    b:  //",
  "    3.14,",
  "  |},",
  "  [",
  '    "fo",',
  '    "fo\'",',
  '    "fo\\"",',
  "    'fo\"',",
  "    'fo\\\"',",
  "    'fo\\\\\"',",
  "  ],",
  "];",
  "",
  "const F: Foo? = {",
  "  a: null,",
  "  b: 3.14,",
  "  c: false,",
  "};",
  "struct S {",
  "  // a",
  "}",
  "",
  "struct So(100) {  // a",
  "  // b",
  "}  // d",
  "",
  "// a",
  "",
  "// c",
  "",
  "// d",
  "",
  "method GetFoo(",
  "  struct {",
  "    a: enum {",
  "      z: int32;",
  "      g: bool;",
  "      h:  //",
  "      [int32  //",
  "      ?];",
  "    };",
  "    b: bool;",
  "  }",
  "): struct {",
  "  x: int32;",
  "  y: int32;",
  "} = 123;",
  "",
  "struct G {",
  "  // a",
  "",
  "  // b",
  "  // b2",
  "",
  "  // c",
  "",
  "  struct WithQuestionMarkStableIdentifier(500000) {}",
  "}",
  "",
  "method WithQuestionMarkStableIdentifier(",
  "  bool",
  "): bool =  /**/",
  "500000;",
  "",
].join("\n");

describe("formatModule", () => {
  it("works", () => {
    const formatted = formatModule(
      UNFORMATTED_MODULE,
      "path/to/module",
      () => 0.5,
    );
    expect(formatted).toMatch({
      newSourceCode: EXPECTED_FORMATTED_MODULE,
      textEdits: [
        {
          oldStart: 0,
          oldEnd: 8,
          newText: "// module",
        },
        {
          oldStart: 8,
          oldEnd: 9,
          newText: "\n\n",
        },
        {
          oldStart: 9,
          oldEnd: 174,
          newText: [
            'import { Foo } from "@gepheum/foo.skir";',
            "",
            'import { A } from "module.skir";',
            'import * as foo from "other_module.skir";',
            "import {",
            "  a,",
            "  b,",
            "  c,",
            '} from "path/to/path/to/other_module.skir";',
          ].join("\n"),
        },
        {
          oldStart: 174,
          oldEnd: 177,
          newText: "\n\n",
        },
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
      ],
      errors: [],
    });
  });

  it("does not add trailing comma after semicolon followed by comment", () => {
    // Regression test: when a scalar const declaration's semicolon is followed
    // by a comment, the "in-value" context was not being reset, causing
    // spurious trailing commas in the next enum/struct.
    const input = [
      'const FOO: string = "bar";',
      "",
      "// Comment before enum",
      "enum E {",
      "  A = 1;",
      "  B = 2;",
      "}",
      "",
    ].join("\n");
    const expected = [
      'const FOO: string = "bar";',
      "",
      "// Comment before enum",
      "enum E {",
      "  A = 1;",
      "  B = 2;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModule(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({
      newSourceCode: expected,
      errors: [],
    });
  });

  it("does not add trailing comma in struct after const with comment", () => {
    const input = [
      'const REGEX: string = "foo";',
      "",
      "// Section",
      "",
      "struct Request {",
      "  id: string;",
      "}",
      "",
    ].join("\n");
    const expected = [
      'const REGEX: string = "foo";',
      "",
      "// Section",
      "",
      "struct Request {",
      "  id: string;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModule(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({
      newSourceCode: expected,
      errors: [],
    });
  });

  // ---------------------------------------------------------------------------
  // Keyed array types
  // ---------------------------------------------------------------------------

  it("formats keyed array field [User|id]", () => {
    const input = "struct Foo { users: [User|id]; }";
    const expected = ["struct Foo {", "  users: [User|id];", "}", ""].join(
      "\n",
    );
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats keyed array with chained field path [Item|a.b.c]", () => {
    const input = "struct Foo { items: [Item|a.b.c]; }";
    const expected = ["struct Foo {", "  items: [Item|a.b.c];", "}", ""].join(
      "\n",
    );
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats keyed array with .kind suffix [WeekdayWorkStatus|weekday.kind]", () => {
    const input = "struct Foo { schedule: [WeekdayWorkStatus|weekday.kind]; }";
    const expected = [
      "struct Foo {",
      "  schedule: [WeekdayWorkStatus|weekday.kind];",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats optional keyed array [User|id]?", () => {
    const input = "struct Foo { users: [User|id]?; }";
    const expected = ["struct Foo {", "  users: [User|id]?;", "}", ""].join(
      "\n",
    );
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  // ---------------------------------------------------------------------------
  // Import with curly-brace syntax
  // ---------------------------------------------------------------------------

  it("formats import with curly braces, single name", () => {
    const input = 'import {Foo} from "mod.skir";\nstruct S { x: Foo; }';
    const expected = [
      'import { Foo } from "mod.skir";',
      "",
      "struct S {",
      "  x: Foo;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats import with curly braces, multiple names sorted alphabetically", () => {
    const input = 'import {Baz,Foo,Bar} from "mod.skir";\nstruct S { x: Foo; }';
    const expected = [
      "import {",
      "  Bar,",
      "  Baz,",
      "  Foo,",
      '} from "mod.skir";',
      "",
      "struct S {",
      "  x: Foo;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  // ---------------------------------------------------------------------------
  // removed keyword
  // ---------------------------------------------------------------------------

  it("formats removed with explicit range 1..3", () => {
    const input = "struct Foo { a: int32 = 0; removed 1..3; b: int32 = 4; }";
    const expected = [
      "struct Foo {",
      "  a: int32 = 0;",
      "  removed 1..3;",
      "  b: int32 = 4;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats removed with mixed comma-separated items and range", () => {
    const input =
      "struct Foo { a: int32 = 0; removed 1, 2..4, 5; b: int32 = 6; }";
    const expected = [
      "struct Foo {",
      "  a: int32 = 0;",
      "  removed 1, 2..4, 5;",
      "  b: int32 = 6;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats implicit removed (no numbers)", () => {
    const input = "struct Foo { a: int32; removed; b: int32; }";
    const expected = [
      "struct Foo {",
      "  a: int32;",
      "  removed;",
      "  b: int32;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats multiple consecutive implicit removed", () => {
    const input =
      "struct Foo { a: int32; removed; removed; removed; b: int32; }";
    const expected = [
      "struct Foo {",
      "  a: int32;",
      "  removed;",
      "  removed;",
      "  removed;",
      "  b: int32;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats implicit removed in enum", () => {
    const input = "enum E { A; removed; B; }";
    const expected = ["enum E {", "  A;", "  removed;", "  B;", "}", ""].join(
      "\n",
    );
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("does not leak removed context after trailing comment", () => {
    // After 'removed 1, 2; // comment', context must reset to null at ';',
    // so that the next struct field is not treated as part of a removed list.
    const input = [
      "struct Foo {",
      "  a: int32 = 0;",
      "  removed 1, 2; // keep these free",
      "  b: int32 = 3;",
      "}",
      "",
    ].join("\n");
    const expected = [
      "struct Foo {",
      "  a: int32 = 0;",
      "  removed 1, 2;  // keep these free",
      "  b: int32 = 3;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  // ---------------------------------------------------------------------------
  // ? stable identifier replacement
  // ---------------------------------------------------------------------------

  it("replaces ? stable id in struct", () => {
    const input = "struct Foo(?) { x: int32; }";
    const expected = "struct Foo(500000) {\n  x: int32;\n}\n";
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("replaces ? stable id in enum", () => {
    const input = "enum Foo(?) { A; }";
    const expected = "enum Foo(500000) {\n  A;\n}\n";
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("replaces ? stable id in method", () => {
    const input = "method Foo(bool): bool = ?;";
    const expected = "method Foo(\n  bool\n): bool = 500000;\n";
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("replaces ? stable id in method with inline struct request", () => {
    const input = "method Foo(struct { a: int32; }): bool = ?;";
    const expected = [
      "method Foo(",
      "  struct {",
      "    a: int32;",
      "  }",
      "): bool = 500000;",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("does not replace ? used as optional type marker", () => {
    const input = "struct Foo { x: int32?; }";
    const expected = "struct Foo {\n  x: int32?;\n}\n";
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  // ---------------------------------------------------------------------------
  // Doc comment normalization
  // ---------------------------------------------------------------------------

  it("adds space after /// when missing", () => {
    const input = "///my comment\nstruct Foo {}";
    const expected = "/// my comment\nstruct Foo {}\n";
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("adds space after // when missing", () => {
    const input = "//my comment\nstruct Foo {}";
    const expected = "// my comment\nstruct Foo {}\n";
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("does not alter empty /// comment", () => {
    const input = "///\nstruct Foo {}";
    const expected = "///\nstruct Foo {}\n";
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  // ---------------------------------------------------------------------------
  // const with partial-default struct {| |}
  // ---------------------------------------------------------------------------

  it("formats const with partial-default struct value {| |}", () => {
    const input = "const X: Foo = {| a: 1, b: true |};";
    const expected = [
      "const X: Foo = {|",
      "  a: 1,",
      "  b: true,",
      "|};",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats const with array of partial-default structs", () => {
    const input = "const X: [Foo] = [{| a: 1 |}, {| b: 2 |}];";
    const expected = [
      "const X: [Foo] = [",
      "  {|",
      "    a: 1,",
      "  |},",
      "  {|",
      "    b: 2,",
      "  |},",
      "];",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  // ---------------------------------------------------------------------------
  // const with nested arrays [[...]]
  // ---------------------------------------------------------------------------

  it("formats const with nested array type [[string]] and value", () => {
    const input = 'const X: [[string]] = [["a", "b"], ["c"]];';
    const expected = [
      "const X: [[string]] = [",
      "  [",
      '    "a",',
      '    "b",',
      "  ],",
      "  [",
      '    "c",',
      "  ],",
      "];",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats struct field with nested array type [[string]]", () => {
    const input = "struct Foo { matrix: [[string]]; }";
    const expected = ["struct Foo {", "  matrix: [[string]];", "}", ""].join(
      "\n",
    );
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  // ---------------------------------------------------------------------------
  // Methods with inline request / response
  // ---------------------------------------------------------------------------

  it("formats method with inline enum response", () => {
    const input = "method Foo(Request): enum { OK; err: string; } = 42;";
    const expected = [
      "method Foo(",
      "  Request",
      "): enum {",
      "  OK;",
      "  err: string;",
      "} = 42;",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats method with inline struct request and inline struct response", () => {
    const input =
      "method Foo(struct { a: int32; b: string; }): struct { ok: bool; code: int32; } = 42;";
    const expected = [
      "method Foo(",
      "  struct {",
      "    a: int32;",
      "    b: string;",
      "  }",
      "): struct {",
      "  ok: bool;",
      "  code: int32;",
      "} = 42;",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats method with deeply nested inline request (enum inside struct)", () => {
    const input =
      "method Foo(struct { a: enum { X; y: struct { z: int32; }; }; }): bool = 1;";
    const expected = [
      "method Foo(",
      "  struct {",
      "    a: enum {",
      "      X;",
      "      y: struct {",
      "        z: int32;",
      "      };",
      "    };",
      "  }",
      "): bool = 1;",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats method with inline struct response containing nested struct", () => {
    const input =
      "method Foo(bool): struct { inner: struct { x: int32; }; } = 1;";
    const expected = [
      "method Foo(",
      "  bool",
      "): struct {",
      "  inner: struct {",
      "    x: int32;",
      "  };",
      "} = 1;",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats method with inline response enum containing nested struct", () => {
    const input =
      "method Foo(bool): enum { OK; error: struct { msg: string; code: int32; }; } = 5;";
    const expected = [
      "method Foo(",
      "  bool",
      "): enum {",
      "  OK;",
      "  error: struct {",
      "    msg: string;",
      "    code: int32;",
      "  };",
      "} = 5;",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats method with comment in request before closing paren", () => {
    // A comment between the request type and the closing ')' should be
    // formatted and must not corrupt the indentation of the ')' line.
    const input =
      "method Foo(\n  MyRequest\n  // some comment\n): MyResponse = 1;";
    const expected = [
      "method Foo(",
      "  MyRequest",
      "  // some comment",
      "): MyResponse = 1;",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  // ---------------------------------------------------------------------------
  // Nesting records inside other records
  // ---------------------------------------------------------------------------

  it("formats enum with nested struct", () => {
    const input =
      "enum Status { OK; struct Error { message: string; } error: Error; }";
    const expected = [
      "enum Status {",
      "  OK;",
      "  struct Error {",
      "    message: string;",
      "  }",
      "  error: Error;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats deeply nested inline struct fields", () => {
    const input = "struct A { b: struct { c: struct { d: int32; }; }; }";
    const expected = [
      "struct A {",
      "  b: struct {",
      "    c: struct {",
      "      d: int32;",
      "    };",
      "  };",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("formats struct and enum with stable identifiers", () => {
    const input = "struct Outer(10) { enum Inner(20) { A; B; } x: Inner; }";
    const expected = [
      "struct Outer(10) {",
      "  enum Inner(20) {",
      "    A;",
      "    B;",
      "  }",
      "  x: Inner;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  // ---------------------------------------------------------------------------
  // const – context must not leak into subsequent declarations
  // ---------------------------------------------------------------------------

  it("does not add trailing comma inside struct after const with object value", () => {
    const input = [
      "const C: Foo = {",
      "  a: 1,",
      "};",
      "struct S {",
      "  x: int32;",
      "}",
      "",
    ].join("\n");
    const expected = [
      "const C: Foo = {",
      "  a: 1,",
      "};",
      "struct S {",
      "  x: int32;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("does not add trailing comma inside struct after const with array value", () => {
    const input = [
      "const C: [int32] = [",
      "  1,",
      "  2,",
      "];",
      "struct S {",
      "  x: int32;",
      "}",
      "",
    ].join("\n");
    const expected = [
      "const C: [int32] = [",
      "  1,",
      "  2,",
      "];",
      "struct S {",
      "  x: int32;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  it("does not treat struct field explicit number as entering const in-value context", () => {
    // `x: int32 = 0` in a struct must not set context to "in-value",
    // which would cause trailing commas in subsequent fields.
    const input = "struct Foo { x: int32 = 0; y: string = 1; }";
    const expected = [
      "struct Foo {",
      "  x: int32 = 0;",
      "  y: string = 1;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  // ---------------------------------------------------------------------------
  // Idempotency
  // ---------------------------------------------------------------------------

  it("is idempotent for struct with keyed array field", () => {
    const input = "struct Foo {\n  users: [User|id];\n}\n";
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: input, errors: [] });
  });

  it("is idempotent for method with inline struct request and response", () => {
    const input = [
      "method Foo(",
      "  struct {",
      "    a: int32;",
      "    b: string;",
      "  }",
      "): struct {",
      "  ok: bool;",
      "  code: int32;",
      "} = 42;",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: input, errors: [] });
  });

  it("is idempotent for const with nested arrays", () => {
    const input = [
      "const X: [[string]] = [",
      "  [",
      '    "a",',
      '    "b",',
      "  ],",
      "  [",
      '    "c",',
      "  ],",
      "];",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: input, errors: [] });
  });

  it("is idempotent for const with partial-default struct array", () => {
    const input = [
      "const X: [Foo] = [",
      "  {|",
      "    a: 1,",
      "  |},",
      "];",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: input, errors: [] });
  });

  it("is idempotent for method with inline enum response", () => {
    const input = [
      "method Foo(",
      "  Request",
      "): enum {",
      "  OK;",
      "  err: string;",
      "} = 42;",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: input, errors: [] });
  });

  it("is idempotent for import with curly braces", () => {
    const input = [
      'import { Foo } from "mod.skir";',
      "",
      "struct S {",
      "  x: Foo;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: input, errors: [] });
  });

  it("is idempotent for removed with range", () => {
    const input = [
      "struct Foo {",
      "  a: int32 = 0;",
      "  removed 1, 2..4, 5;",
      "  b: int32 = 6;",
      "}",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: input, errors: [] });
  });

  it("is idempotent for enum with removed", () => {
    const input = ["enum E {", "  A;", "  removed;", "  B;", "}", ""].join(
      "\n",
    );
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: input, errors: [] });
  });

  it("is idempotent for deeply nested inline method request", () => {
    const input = [
      "method Foo(",
      "  struct {",
      "    a: enum {",
      "      X;",
      "      y: struct {",
      "        z: int32;",
      "      };",
      "    };",
      "  }",
      "): bool = 1;",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir", () => 0.5);
    expect(formatted).toMatch({ newSourceCode: input, errors: [] });
  });

  // ---------------------------------------------------------------------------
  // Trailing comment between '}' of inline response struct and '= <id>'
  // ---------------------------------------------------------------------------

  it("formats method where a comment separates '}' of inline response from '= <id>;'", () => {
    // When a line comment sits between the closing '}' of the inline response
    // struct and the stable-id assignment '= 42;', the formatter moves '= 42;'
    // to a new line.  The result is valid Skir and parses correctly.
    const input = "method Foo(bool): struct { x: int32; } // comment\n= 42;";
    const expected = [
      "method Foo(",
      "  bool",
      "): struct {",
      "  x: int32;",
      "}  // comment",
      "= 42;",
      "",
    ].join("\n");
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ newSourceCode: expected, errors: [] });
  });

  // ---------------------------------------------------------------------------
  // Leading whitespace / content removal before the first token
  // ---------------------------------------------------------------------------

  it("strips leading spaces before the first token and emits a delete textEdit", () => {
    const input = "   struct Foo {}";
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ errors: [] });
    // The first textEdit must delete exactly the 3 leading spaces.
    expect(formatted.textEdits[0]).toMatch({
      oldStart: 0,
      oldEnd: 3,
      newText: "",
    });
    // The formatted output must not start with any leading whitespace.
    if (!formatted.newSourceCode.startsWith("struct")) {
      throw new Error(
        `Expected newSourceCode to start with 'struct', got: ${JSON.stringify(formatted.newSourceCode.slice(0, 20))}`,
      );
    }
  });

  it("strips leading newlines before the first token and emits a delete textEdit", () => {
    const input = "\n\nimport * as foo from 'foo.skir';";
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ errors: [] });
    // The first textEdit must delete exactly the 2 leading newlines.
    expect(formatted.textEdits[0]).toMatch({
      oldStart: 0,
      oldEnd: 2,
      newText: "",
    });
    if (!formatted.newSourceCode.startsWith("import")) {
      throw new Error(
        `Expected newSourceCode to start with 'struct', got: ${JSON.stringify(formatted.newSourceCode.slice(0, 20))}`,
      );
    }
  });

  it("does not emit a leading-delete textEdit when the first token is at position 0", () => {
    // firstBlockStart == 0, so the `if (firstBlockStart > 0)` branch is not
    // taken and no delete edit should be pushed for position 0.
    const input = "struct Foo {}";
    const formatted = formatModuleAndCheck(input, "test.skir");
    expect(formatted).toMatch({ errors: [] });
    const hasLeadingDeleteEdit = formatted.textEdits.some(
      (e) => e.oldStart === 0 && e.oldEnd > 0 && e.newText === "",
    );
    if (hasLeadingDeleteEdit) {
      throw new Error("Expected no leading-delete textEdit but found one");
    }
  });
});
