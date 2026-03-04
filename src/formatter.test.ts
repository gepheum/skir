import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { formatModule } from "./formatter.js";

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
});
