import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { formatModule } from "./formatter.js";
import { parseModule } from "./parser.js";
import { tokenizeModule } from "./tokenizer.js";

const UNFORMATTED_MODULE = `//module
import A from 'module.skir';  import * as foo from 'module.skir';
import  a,b,c  from  'module.skir';

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
  'import A from "module.skir";',
  'import * as foo from "module.skir";',
  'import a, b, c from "module.skir";',
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
  "method M(Request): Response = 123;",
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
  "method WithQuestionMarkStableIdentifier(bool): bool =  /**/",
  "500000;",
  "",
].join("\n");

describe("formatModule", () => {
  it("works", () => {
    const tokens = tokenizeModule(UNFORMATTED_MODULE, "path/to/module");
    expect(tokens.errors).toMatch([]);
    const parsedModule = parseModule(tokens.result, "lenient");
    expect(parsedModule.errors).toMatch([]);
    const formatted = formatModule(tokens.result, () => 0.5);
    expect(formatted).toMatch({
      newSourceCode: EXPECTED_FORMATTED_MODULE,
      textEdits: [
        {
          oldStart: 0,
          oldEnd: 8,
          newText: "// module",
        },
        {
          oldStart: 23,
          oldEnd: 36,
          newText: '"module.skir"',
        },
        {
          oldStart: 37,
          oldEnd: 39,
          newText: "\n",
        },
        {
          oldStart: 60,
          oldEnd: 73,
        },
        {
          oldStart: 81,
          oldEnd: 83,
          newText: " ",
        },
        {
          oldStart: 85,
          oldEnd: 85,
          newText: " ",
        },
        {
          oldStart: 87,
          oldEnd: 87,
          newText: " ",
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
        {
          newText: "500000",
        },
        {},
        {},
        {},
        {},
        {},
        {
          newText: "500000",
        },
        {},
      ],
    });
  });
});
