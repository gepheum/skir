import { expect } from "buckwheat";
import { describe, it } from "node:test";
import type { FileReader } from "./io.js";
import { ModuleSet } from "./module_set.js";

class FakeFileReader implements FileReader {
  readTextFile(modulePath: string): string | undefined {
    return this.pathToCode.get(modulePath);
  }

  pathToCode = new Map<string, string>();
}

describe("module set", () => {
  it("works", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        import * as other_module from "./other/module";

        struct Outer {
          struct Foo {}
        }

        struct Bar(100) {
          foo: Outer.Foo;
          foo2: .Outer.Foo;

          struct Inner(101) {}
          inner: Inner;
          zoo: other_module.Outer.Zoo;

          loo_loo: struct {};
        }

        method GetBar(Outer.Foo): Bar = 123;
        method GetBar2(Outer.Foo): Bar = 100;
        method Search(enum {}): struct {} = 456;
      `,
    );
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/other/module",
      `
        struct Outer {
          struct Zoo {}
        }
      `,
    );
    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({
      result: {
        nameToDeclaration: {
          other_module: {
            kind: "import-alias",
            name: {
              text: "other_module",
            },
            modulePath: {
              text: '"./other/module"',
            },
          },
          Outer: {
            kind: "record",
            name: {
              text: "Outer",
            },
            recordType: "struct",
            nameToDeclaration: {
              Foo: {
                kind: "record",
              },
            },
            declarations: [
              {
                name: {
                  text: "Foo",
                },
              },
            ],
            nestedRecords: [
              {
                recordType: "struct",
                name: {
                  text: "Foo",
                },
                nestedRecords: [],
              },
            ],
          },
          Bar: {
            kind: "record",
            recordType: "struct",
            name: {
              text: "Bar",
            },
            fields: [
              {
                kind: "field",
                name: {
                  text: "foo",
                },
                number: 0,
                type: {
                  kind: "record",
                  key: "path/to/module:98",
                  recordType: "struct",
                  refToken: {
                    text: "Foo",
                  },
                },
              },
              { name: { text: "foo2" } },
              { name: { text: "inner" } },
              { name: { text: "zoo" } },
              { name: { text: "loo_loo" } },
            ],
            numSlots: 5,
            numSlotsInclRemovedNumbers: 5,
          },
          GetBar: {
            kind: "method",
            name: { text: "GetBar" },
            requestType: {
              kind: "record",
              key: "path/to/module:98",
              recordType: "struct",
              refToken: {
                text: "Foo",
              },
            },
            responseType: {
              kind: "record",
              key: "path/to/module:131",
              recordType: "struct",
              refToken: {
                text: "Bar",
              },
            },
            number: 123,
          },
          GetBar2: {
            number: 100,
          },
          Search: {},
          SearchRequest: {
            name: {
              text: "SearchRequest",
              originalText: "Search",
            },
          },
          SearchResponse: {},
        },
        declarations: [
          { name: { text: "other_module" } },
          { name: { text: "Outer" } },
          { name: { text: "Bar" } },
          { name: { text: "GetBar" } },
          { name: { text: "GetBar2" } },
          { name: { text: "Search" } },
          { name: { text: "SearchRequest" } },
          { name: { text: "SearchResponse" } },
        ],
        records: [
          { record: { name: { text: "Foo" } } },
          { record: { name: { text: "Outer" } } },
          { record: { name: { text: "Inner" }, recordNumber: 101 } },
          { record: { name: { text: "LooLoo" } } },
          { record: { name: { text: "Bar" } } },
          { record: { name: { text: "SearchRequest" } } },
          { record: { name: { text: "SearchResponse" } } },
        ],
      },
      errors: [],
    });
  });

  it("recursivity works", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        struct A { s: string; }
        struct B { b: B; }
        struct C { c: C?; }
        struct D { d: [D]; }
        struct E { f: F; }
        struct F { e: E; }
        struct G { b: B; }
        struct H { i: I; }
        enum I { h: H; }
      `,
    );
    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({
      result: {
        nameToDeclaration: {
          A: {
            fields: [{ isRecursive: false }],
          },
          B: {
            fields: [{ isRecursive: "hard" }],
          },
          C: {
            fields: [{ isRecursive: "soft" }],
          },
          D: {
            fields: [{ isRecursive: "soft" }],
          },
          E: {
            fields: [{ isRecursive: "hard" }],
          },
          F: {
            fields: [{ isRecursive: "hard" }],
          },
          G: {
            fields: [{ isRecursive: false }],
          },
          H: {
            fields: [{ isRecursive: "soft" }],
          },
          I: {
            fields: [{ isRecursive: "soft" }],
          },
        },
      },
      errors: [],
    });
  });

  it("circular dependency between modules", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        import * as other_module from "./other/module";
      `,
    );
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/other/module",
      `
        import * as module from "path/to/module";
      `,
    );
    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({
      errors: [
        {
          token: {
            text: '"./other/module"',
          },
          message: "Circular dependency between modules",
        },
      ],
    });
    expect(moduleSet.parseAndResolve("path/to/other/module")).toMatch({
      errors: [
        {
          token: {
            text: '"path/to/module"',
          },
          message: "Circular dependency between modules",
        },
      ],
    });
  });

  it("module not found", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        import * as other_module from "./other/module";
      `,
    );

    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({
      errors: [
        {
          token: {
            text: '"./other/module"',
          },
          message: "Module not found",
        },
      ],
    });
  });

  it("module already imported with an alias", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        import * as other_module from "./other/module";
        import Foo from "./other/module";
      `,
    );
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/other/module",
      `
        struct Foo {}
      `,
    );

    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({
      errors: [
        {
          token: {
            text: '"./other/module"',
          },
          message: "Module already imported with an alias",
        },
      ],
    });
  });

  it("module already imported with a different alias", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        import * as foo from "./other/module";
        import * as bar from "./other/module";
      `,
    );
    fakeFileReader.pathToCode.set("path/to/root/path/to/other/module", "");

    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({
      errors: [
        {
          token: {
            text: '"./other/module"',
          },
          message: "Module already imported with a different alias",
        },
      ],
    });
  });

  it("multiple import declarations from same module", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        import Foo from "./other/module";
        import Bar from "./other/module";

        struct Zoo {
          foo: Foo;
          bar: Bar;
        }
      `,
    );
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/other/module",
      `
        struct Foo {}
        struct Bar {}
      `,
    );

    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({
      errors: [],
    });
  });

  it("multiple imports from same module", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        import Foo, Bar from "./other/module";

        struct Zoo {
          foo: Foo;
          bar: Bar;
        }
      `,
    );
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/other/module",
      `
        struct Foo {}
        struct Bar {}
      `,
    );

    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({
      errors: [],
    });
  });

  it("module path cannot contain backslash", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        import * as foo from ".\\\\module";
      `,
    );
    fakeFileReader.pathToCode.set("path/to/root/path/to/other/module", "");

    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({
      errors: [
        {
          token: {
            text: '".\\\\module"',
          },
          message: "Replace backslash with slash",
        },
      ],
    });
  });

  it("field numbering constraint satisfied", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        struct Foo {}
        struct Bar { bar: int32 = 0; }
        struct Zoo { foo: Foo = 0; bar: Bar = 1; }
      `,
    );

    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({ errors: [] });
  });

  describe("keyed arrays", () => {
    it("works", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
          struct Outer {
            struct User {
              key: string;
              key_enum: Enum;
            }

            enum Enum {
              MONDAY;
            }

            struct UserHistory {
              user: User;
            }
          }

          struct Foo {
            users: [Outer.User|key];
            users_by_enum: [Outer.User|key_enum.kind];
            user_histories: [Outer.UserHistory|user.key]?;
          }
        `,
      );

      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Foo: {
              fields: [
                {
                  name: { text: "users" },
                  type: {
                    kind: "array",
                    item: {
                      kind: "record",
                      key: "path/to/module:45",
                    },
                    key: {
                      pipeToken: { text: "|" },
                      path: [{ name: { text: "key" } }],
                      keyType: {
                        kind: "primitive",
                        primitive: "string",
                      },
                    },
                  },
                },
                {
                  name: { text: "users_by_enum" },
                  type: {
                    kind: "array",
                    item: {
                      kind: "record",
                      key: "path/to/module:45",
                    },
                    key: {
                      pipeToken: { text: "|" },
                      path: [
                        {
                          name: { text: "key_enum" },
                          declaration: { name: { text: "key_enum" } },
                        },
                        { name: { text: "kind" }, declaration: undefined },
                      ],
                      keyType: {
                        kind: "record",
                        key: "path/to/module:141",
                      },
                    },
                  },
                },
                {
                  name: { text: "user_histories" },
                  type: {
                    kind: "optional",
                    other: {
                      kind: "array",
                      item: {
                        kind: "record",
                        key: "path/to/module:204",
                      },
                      key: {
                        pipeToken: { text: "|" },
                        path: [
                          { name: { text: "user" } },
                          { name: { text: "key" } },
                        ],
                        keyType: {
                          kind: "primitive",
                          primitive: "string",
                        },
                      },
                    },
                  },
                },
              ],
            },
          },
        },
      });
    });

    it("field not found in struct", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
          struct User { b: bool; c: bool; }
          struct Foo {
            users: [User|key];
          }
        `,
      );

      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: "key",
            },
            message: "Field not found in struct User",
            expectedNames: ["b", "c"],
          },
        ],
      });
    });

    it("item must have struct type", () => {
      // This is actually verified at parsing time.

      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
          struct Foo {
            users: [string|key];
          }
        `,
      );

      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: "|",
            },
            expected: "']'",
          },
        ],
      });
    });

    it("must have struct type", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
          struct User {
            key: string;
          }
          struct Foo {
            users: [User|key.bar];
          }
        `,
      );

      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: "key",
            },
            message: "Must have struct type",
          },
        ],
      });
    });

    it("if enum then expects kind", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
          enum Enum { MONDAY; }
          struct Foo {
            users: [Enum|key];
          }
        `,
      );

      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: "key",
            },
            expected: "'kind'",
          },
        ],
      });
    });

    it("all fields but the last must have struct type", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
          struct User { key: string; }
          struct Foo {
            users: [User|key.bar];
          }
        `,
      );

      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: "key",
            },
            message: "Must have struct type",
          },
        ],
      });
    });

    it("key must have primitive or enum type", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
          struct Bar {}
          struct User { key: Bar; }
          struct Foo {
            users: [User|key];
          }
        `,
      );

      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: "key",
            },
            message: "Does not have primitive type",
          },
        ],
      });
    });

    it("method and constant types are validated", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
          struct Foo { foo: bool; struct Bar{} }

          method Pa([Foo|a]): string = 1;
          method Pb(string): [Foo|b] = 2;
          const FOO: [Foo|c] = [];
          const PI: float32 = -3.14;
        `,
      );

      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: "a",
            },
            message: "Field not found in struct Foo",
            expectedNames: ["foo"],
          },
          {
            token: {
              text: "b",
            },
            message: "Field not found in struct Foo",
            expectedNames: ["foo"],
          },
          {
            token: {
              text: "c",
            },
            message: "Field not found in struct Foo",
            expectedNames: ["foo"],
          },
        ],
      });
    });
  });

  describe("type resolver", () => {
    it("cannot find name", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
          struct Foo {
            bar: Bar;
          }

          struct Zoo {
            o: other_module.O;
          }

          import * as other_module from "./other/module";
        `,
      );
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/other/module",
        `
          struct O {}
        `,
      );

      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: "Bar",
            },
            message: "Cannot find name 'Bar'",
            expectedNames: ["Foo", "Zoo", "other_module"],
          },
        ],
      });
    });

    describe("cannot reimport imported name", () => {
      it("no alias / no alias", () => {
        const fakeFileReader = new FakeFileReader();
        fakeFileReader.pathToCode.set(
          "path/to/root/path/to/foo",
          `
          struct Foo {}
        `,
        );
        fakeFileReader.pathToCode.set(
          "path/to/root/path/to/bar",
          `
          import Foo from "./foo";
          struct Bar { foo: Foo; }
        `,
        );
        fakeFileReader.pathToCode.set(
          "path/to/root/path/to/module",
          `
          import Foo from "./bar";
          struct Zoo { foo: Foo; }
        `,
        );

        const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
        const actual = moduleSet.parseAndResolve("path/to/module");

        expect(actual).toMatch({
          errors: [
            {
              token: {
                text: "Foo",
                position: 18,
              },
              message: "Cannot reimport imported record",
            },
          ],
        });
      });

      it("no alias / alias", () => {
        const fakeFileReader = new FakeFileReader();
        fakeFileReader.pathToCode.set(
          "path/to/root/path/to/foo",
          `
          struct Foo {}
        `,
        );
        fakeFileReader.pathToCode.set(
          "path/to/root/path/to/bar",
          `
          import * as foo from "./foo";
          struct Bar { foo: foo.Foo; }
        `,
        );
        fakeFileReader.pathToCode.set(
          "path/to/root/path/to/module",
          `
          import foo, DoesNotExist from "./bar";
          struct Zoo { foo: foo.Foo; }
        `,
        );

        const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
        const actual = moduleSet.parseAndResolve("path/to/module");

        expect(actual).toMatch({
          errors: [
            {
              token: {
                text: "foo",
                position: 18,
              },
              message: "Not a record",
            },
            {
              token: {
                text: "DoesNotExist",
              },
              message: "Not found",
            },
          ],
        });
      });

      it("alias / no alias", () => {
        const fakeFileReader = new FakeFileReader();
        fakeFileReader.pathToCode.set(
          "path/to/root/path/to/foo",
          `
          struct Foo {}
        `,
        );
        fakeFileReader.pathToCode.set(
          "path/to/root/path/to/bar",
          `
          import Foo from "./foo";
          struct Bar { foo: Foo; }
        `,
        );
        fakeFileReader.pathToCode.set(
          "path/to/root/path/to/module",
          `
          import * as bar from "./bar";
          struct Zoo { foo: bar.Foo; }
        `,
        );

        const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
        const actual = moduleSet.parseAndResolve("path/to/module");

        expect(actual).toMatch({
          errors: [
            {
              token: {
                text: "Foo",
              },
              message: "Cannot refer to imports of imported module",
            },
          ],
        });
      });

      it("alias / alias", () => {
        const fakeFileReader = new FakeFileReader();
        fakeFileReader.pathToCode.set(
          "path/to/root/path/to/foo",
          `
          struct Foo {}
        `,
        );
        fakeFileReader.pathToCode.set(
          "path/to/root/path/to/bar",
          `
          import * as foo from "./foo";
          struct Bar { foo: foo.Foo; }
        `,
        );
        fakeFileReader.pathToCode.set(
          "path/to/root/path/to/module",
          `
          import * as bar from "./bar";
          struct Zoo { foo: bar.foo.Foo; }
        `,
        );

        const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
        const actual = moduleSet.parseAndResolve("path/to/module");

        expect(actual).toMatch({
          errors: [
            {
              token: {
                text: "foo",
              },
              message: "Cannot refer to imports of imported module",
            },
          ],
        });
      });
    });
  });

  it("import module with absolute path", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        import Bar from "path/to_other_module";

        struct Foo {
          bar: Bar;
        }
      `,
    );
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to_other_module",
      `
        struct Bar {}
      `,
    );

    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({
      errors: [],
    });
  });

  it("normalize module path", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        import Bar from "../foo/../to_other_module";

        struct Foo {
          bar: Bar;
        }
      `,
    );
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to_other_module",
      `
        struct Bar {}
      `,
    );

    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({
      errors: [],
    });
  });

  it("module path must point to a file within root", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        import Bar from "../../../other_module";

        struct Foo {
          bar: Bar;
        }
      `,
    );
    fakeFileReader.pathToCode.set(
      "path/to/other_module",
      `
        struct Bar {}
      `,
    );

    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({
      errors: [
        {
          token: {
            text: '"../../../other_module"',
          },
          message: "Module path must point to a file within root",
        },
      ],
    });
  });

  it("all imports must be used", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        import Bar, Zoo from "./other_module";

        struct Foo {
          zoo: Zoo;
        }
      `,
    );
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/other_module",
      `
        struct Bar {}
        struct Zoo {}
      `,
    );

    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");

    expect(actual).toMatch({
      errors: [
        {
          token: {
            text: "Bar",
          },
          message: "Unused import",
        },
      ],
    });
  });

  it("all stable ids must be distinct", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        struct Foo(100) {}
      `,
    );
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/other_module",
      `
        struct Bar(100) {}
      `,
    );

    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    {
      const actual = moduleSet.parseAndResolve("path/to/module");
      expect(actual).toMatch({
        errors: [],
      });
    }
    {
      const actual = moduleSet.parseAndResolve("path/to/other_module");
      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: "Bar",
            },
            message: "Same number as Foo in path/to/module",
          },
        ],
      });
    }
  });

  it("all method numbers must be distinct", () => {
    const fakeFileReader = new FakeFileReader();
    fakeFileReader.pathToCode.set(
      "path/to/root/path/to/module",
      `
        method GetFoo(string): string = 2103196129;
        method GetBar(string): string = 2103196129;
      `,
    );

    const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
    const actual = moduleSet.parseAndResolve("path/to/module");
    expect(actual).toMatch({
      errors: [
        {
          token: {
            text: "GetBar",
          },
          message: "Same number as GetFoo in path/to/module",
        },
      ],
    });
  });

  describe("constants", () => {
    it("works", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
        struct Color {
          r: int32;
          g: int32;
          b: int32;
        }

        struct Point {
          x: float32;
          removed;
          y: float32;
        }

        struct Shape {
          color: Color;
          points: [Point];
        }

        const MY_SHAPE: Shape = {
          color: {
            r: 255,
            g: 0,
            b: 0,
          },
          points: [
            {
              x: 10.0,
              y: 10.0,
            },
            {|
              y: 20.0,
            |},
            {
              x: 10.0,
              y: 0.0,
            },
          ],
        };
        const NULL_SHAPE: Shape? = null;
      `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            MY_SHAPE: {
              kind: "constant",
              name: {
                text: "MY_SHAPE",
              },
              type: {
                kind: "record",
                key: "path/to/module:207",
                recordType: "struct",
                refToken: {
                  text: "Shape",
                },
              },
              value: {
                kind: "object",
                token: {
                  text: "{",
                },
                entries: {
                  color: {
                    name: {
                      text: "color",
                    },
                    value: {
                      kind: "object",
                      token: {
                        text: "{",
                      },
                      entries: {
                        r: {
                          value: {
                            kind: "literal",
                            token: {
                              text: "255",
                            },
                            type: {
                              kind: "primitive",
                              primitive: "int32",
                            },
                          },
                        },
                        g: {},
                        b: {},
                      },
                      record: {
                        key: "path/to/module:16",
                      },
                    },
                  },
                  points: {
                    value: {
                      kind: "array",
                      token: {
                        text: "[",
                      },
                      items: [
                        {
                          kind: "object",
                          token: {
                            text: "{",
                          },
                          entries: {
                            x: {
                              value: {
                                kind: "literal",
                                token: {
                                  text: "10.0",
                                },
                                type: {
                                  kind: "primitive",
                                  primitive: "float32",
                                },
                              },
                            },
                            y: {},
                          },
                          record: {
                            key: "path/to/module:110",
                          },
                        },
                        {},
                        {},
                      ],
                    },
                  },
                },
                record: {
                  key: "path/to/module:207",
                },
              },
              valueAsDenseJson: [[255], [[10, 0, 10], [0, 0, 20], [10]]],
            },
            NULL_SHAPE: {
              kind: "constant",
              type: {
                kind: "optional",
                other: {
                  refToken: {
                    text: "Shape",
                  },
                },
              },
              value: {
                kind: "literal",
                token: {
                  text: "null",
                },
                type: {
                  kind: "null",
                },
              },
              valueAsDenseJson: null,
            },
          },
          constants: [{}, {}],
        },
        errors: [],
      });
    });

    it("honors default values", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
        struct Struct {
          opt_a: int32?;
          int: int32;
          float: float32;
          bool: bool;
          ints: [int32];
          opt_b: int32?;
        }

        const S: Struct = {
          opt_a: 0,
          int: 0,
          float: 0.0,
          bool: false,
          ints: [],
          opt_b: null,
        };
      `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            S: {
              kind: "constant",
              name: {
                text: "S",
              },
              valueAsDenseJson: [0],
            },
          },
        },
        errors: [],
      });
    });

    it("with keyed array", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
        enum Enum {
          A;
          B;
          c: string;
        }
        struct EnumWrapper {
          e: Enum;
        }
        struct Bar {
          x: int32;
        }
        struct Foo {
          enums: [EnumWrapper|e.kind];
          bars: [Bar|x]?;
        }

        const FOO: Foo = {
          enums: [
            {
              e: "A",
            },
            {
              e: "B",
            },
            {
              e: "UNKNOWN",
            },
            {
              e: {
                kind: "c",
                value: "v",
              },
            },
          ],
          bars: [
            {
              x: 0,
            },
          ],
        };
      `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [],
      });
    });

    it("type error", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
          struct Color {
            r: int32;
            g: int32;
            b: int32;
          }
  
          const BLUE: Color = {
            r: 0,
            g: 0,
            b: 255.0,
          };
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: "255.0",
            },
            expected: "int32",
          },
        ],
      });
    });

    it("key missing from keyed array", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
        enum Enum {
          A;
          B;
        }
        struct EnumWrapper {
          e: Enum;
        }
        struct Foo {
          enums: [EnumWrapper|e.kind];
        }

        const FOO: Foo = {
          enums: [
            {
              e: "A",
            },
            {
            },
          ],
        };
      `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: "{",
            },
            message: "Missing entry: e",
          },
        ],
      });
    });

    it("duplicate key in keyed array", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
        enum Enum {
          A;
          B;
        }
        struct EnumWrapper {
          e: Enum;
        }
        struct Foo {
          enums: [EnumWrapper|e.kind];
        }

        const FOO: Foo = {
          enums: [
            {
              e: "A",
            },
            {
              e: 'A',
            },
          ],
        };
      `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: '"A"',
            },
            message: "Duplicate key",
          },
          {
            token: {
              text: "'A'",
            },
            message: "Duplicate key",
          },
        ],
      });
    });

    it("struct field not found", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
        struct Point {
          x: int32;
          y: int32;
        }

        const POINT: Point = {|
          z: 10,
        |};
      `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: "z",
            },
            message: "Field not found in struct Point",
            expectedNames: ["x", "y"],
          },
        ],
      });
    });

    it("wrapper variant not found", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
        enum Enum {
          foo: int32;
          K;
        }

        const ENUM: Enum = {
          kind: "bar",
          value: 10,
        };
      `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: '"bar"',
            },
            message: "Variant not found in enum Enum",
            expectedNames: ["foo"],
          },
        ],
      });
    });

    it("constant variant not found", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
        enum Enum {
          foo: int32;
          K;
        }

        const ENUM: Enum = "Z";
      `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: '"Z"',
            },
            message: "Variant not found in enum Enum",
            expectedNames: ["UNKNOWN", "K"],
          },
        ],
      });
    });

    it("missing struct field", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
        struct Point {
          x: int32;
          y: int32;
        }

        const POINT: Point = {
          x: 10,
        };
      `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        errors: [
          {
            token: {
              text: "{",
            },
            message: "Missing entry: y",
          },
        ],
      });
    });

    it("missing struct field okay if partial", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/path/to/module",
        `
        struct Point {
          x: int32;
          y: int32;
        }

        const POINT: Point = {|
          x: 10,
        |};
      `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("path/to/module");

      expect(actual).toMatch({
        result: {
          constants: [
            {
              name: {
                text: "POINT",
              },
              valueAsDenseJson: [10],
            },
          ],
        },
        errors: [],
      });
    });
  });

  describe("doc comment references", () => {
    it("resolves reference to enum field", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          /// Hello [Bar.OK]
          struct Foo {
            x: int32;
          }

          enum Bar { OK; }
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Foo: {
              name: { text: "Foo" },
              doc: {
                pieces: [
                  { kind: "text", text: "Hello " },
                  {
                    kind: "reference",
                    nameParts: [
                      {
                        token: { text: "Bar" },
                        declaration: { kind: "record", name: { text: "Bar" } },
                      },
                      {
                        token: { text: "OK" },
                        declaration: { kind: "field", name: { text: "OK" } },
                      },
                    ],
                    referee: {
                      kind: "field",
                      field: { name: { text: "OK" } },
                      record: { name: { text: "Bar" } },
                    },
                  },
                ],
              },
            },
          },
        },
        errors: [],
      });
    });

    it("resolves reference to sibling field", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          struct Foo {
            x: int32;
            /// Must be different from [x]
            y: int32;
          }
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          records: [
            {
              record: {
                fields: [
                  { name: { text: "x" } },
                  {
                    name: { text: "y" },
                    doc: {
                      pieces: [
                        { kind: "text", text: "Must be different from " },
                        {
                          kind: "reference",
                          nameParts: [
                            {
                              token: { text: "x" },
                              declaration: {
                                kind: "field",
                                name: { text: "x" },
                              },
                            },
                          ],
                          referee: {
                            kind: "field",
                            field: { name: { text: "x" } },
                            record: { name: { text: "Foo" } },
                          },
                        },
                      ],
                    },
                  },
                ],
              },
            },
          ],
        },
        errors: [],
      });
    });

    it("resolves reference to record", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          /// See [Bar] for details
          struct Foo {
            x: int32;
          }

          struct Bar {}
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Foo: {
              name: { text: "Foo" },
              doc: {
                pieces: [
                  { kind: "text", text: "See " },
                  {
                    kind: "reference",
                    nameParts: [
                      {
                        token: { text: "Bar" },
                        declaration: { kind: "record", name: { text: "Bar" } },
                      },
                    ],
                    referee: { kind: "record", name: { text: "Bar" } },
                  },
                  { kind: "text", text: " for details" },
                ],
              },
            },
          },
        },
        errors: [],
      });
    });

    it("resolves reference to nested record", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          /// Uses [Outer.Inner]
          struct Foo {
            x: int32;
          }

          struct Outer {
            struct Inner {}
          }
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Foo: {
              name: { text: "Foo" },
              doc: {
                pieces: [
                  { kind: "text", text: "Uses " },
                  {
                    kind: "reference",
                    nameParts: [
                      {
                        token: { text: "Outer" },
                        declaration: {
                          kind: "record",
                          name: { text: "Outer" },
                        },
                      },
                      {
                        token: { text: "Inner" },
                        declaration: {
                          kind: "record",
                          name: { text: "Inner" },
                        },
                      },
                    ],
                    referee: { kind: "record", name: { text: "Inner" } },
                  },
                ],
              },
            },
          },
        },
        errors: [],
      });
    });

    it("resolves absolute reference", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          struct Outer {
            /// Reference to [.Bar]
            struct Inner {}
            struct Bar {}
          }

          struct Bar {}
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Outer: {
              name: { text: "Outer" },
              nestedRecords: [
                {
                  name: { text: "Inner" },
                  doc: {
                    pieces: [
                      { kind: "text", text: "Reference to " },
                      {
                        kind: "reference",
                        absolute: true,
                        nameParts: [
                          {
                            token: { text: "Bar" },
                            declaration: {
                              kind: "record",
                              name: { text: "Bar", colNumber: 17 },
                            },
                          },
                        ],
                        referee: {
                          kind: "record",
                          name: { text: "Bar", colNumber: 17 },
                        },
                      },
                    ],
                  },
                },
                {
                  name: { text: "Bar", colNumber: 19 },
                },
              ],
            },
          },
        },
        errors: [],
      });
    });

    it("resolves reference to method", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          /// Calls [GetData]
          struct Foo {}

          method GetData(Foo): Foo = 123;
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          records: [
            {
              record: {
                name: { text: "Foo" },
                doc: {
                  pieces: [
                    { kind: "text", text: "Calls " },
                    {
                      kind: "reference",
                      nameParts: [
                        {
                          token: { text: "GetData" },
                          declaration: {
                            kind: "method",
                            name: { text: "GetData" },
                          },
                        },
                      ],
                      referee: { kind: "method", name: { text: "GetData" } },
                    },
                  ],
                },
              },
            },
          ],
        },
        errors: [],
      });
    });

    it("resolves reference to constant", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          /// Default is [DEFAULT_VALUE]
          struct Foo {
            x: int32;
          }

          const DEFAULT_VALUE: int32 = 42;
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          records: [
            {
              record: {
                name: { text: "Foo" },
                doc: {
                  pieces: [
                    { kind: "text", text: "Default is " },
                    {
                      kind: "reference",
                      nameParts: [
                        {
                          token: { text: "DEFAULT_VALUE" },
                          declaration: {
                            kind: "constant",
                            name: { text: "DEFAULT_VALUE" },
                          },
                        },
                      ],
                      referee: {
                        kind: "constant",
                        name: { text: "DEFAULT_VALUE" },
                      },
                    },
                  ],
                },
              },
            },
          ],
        },
        errors: [],
      });
    });

    it("resolves reference from field type scope", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          struct Foo {
            /// Uses [OK] from the Bar enum
            bar: Bar;
          }

          enum Bar { OK; }
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Foo: {
              name: { text: "Foo" },
              fields: [
                {
                  name: { text: "bar" },
                  doc: {
                    pieces: [
                      { kind: "text", text: "Uses " },
                      {
                        kind: "reference",
                        nameParts: [
                          {
                            token: { text: "OK" },
                            declaration: {
                              kind: "field",
                              name: { text: "OK" },
                            },
                          },
                        ],
                        referee: {
                          kind: "field",
                          field: { name: { text: "OK" } },
                          record: { name: { text: "Bar" } },
                        },
                      },
                      { kind: "text", text: " from the Bar enum" },
                    ],
                  },
                },
              ],
            },
          },
        },
        errors: [],
      });
    });

    it("resolves reference from method request type scope", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          struct Request {
            x: int32;
          }

          struct Response {}

          /// Input [x] must be positive
          method DoWork(Request): Response = 123;
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          methods: [
            {
              name: { text: "DoWork" },
              doc: {
                pieces: [
                  { kind: "text", text: "Input " },
                  {
                    kind: "reference",
                    nameParts: [
                      {
                        token: { text: "x" },
                        declaration: { kind: "field", name: { text: "x" } },
                      },
                    ],
                    referee: {
                      kind: "field",
                      field: { name: { text: "x" } },
                      record: { name: { text: "Request" } },
                    },
                  },
                  { kind: "text", text: " must be positive" },
                ],
              },
            },
          ],
        },
        errors: [],
      });
    });

    it("resolves reference from constant type scope", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          enum Status { OK; }

          /// Default status is [OK]
          const DEFAULT_STATUS: Status = "OK";
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          constants: [
            {
              name: { text: "DEFAULT_STATUS" },
              doc: {
                pieces: [
                  { kind: "text", text: "Default status is " },
                  {
                    kind: "reference",
                    nameParts: [
                      {
                        token: { text: "OK" },
                        declaration: { kind: "field", name: { text: "OK" } },
                      },
                    ],
                    referee: {
                      kind: "field",
                      field: { name: { text: "OK" } },
                      record: { name: { text: "Status" } },
                    },
                  },
                ],
              },
            },
          ],
        },
        errors: [],
      });
    });

    it("resolves multiple references in same doc comment", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          /// Compare [Foo] and [Bar]
          struct Baz {}

          struct Foo {}
          struct Bar {}
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Baz: {
              name: { text: "Baz" },
              doc: {
                pieces: [
                  { kind: "text", text: "Compare " },
                  {
                    kind: "reference",
                    nameParts: [
                      {
                        token: { text: "Foo" },
                        declaration: { kind: "record", name: { text: "Foo" } },
                      },
                    ],
                    referee: { kind: "record", name: { text: "Foo" } },
                  },
                  { kind: "text", text: " and " },
                  {
                    kind: "reference",
                    nameParts: [
                      {
                        token: { text: "Bar" },
                        declaration: { kind: "record", name: { text: "Bar" } },
                      },
                    ],
                    referee: { kind: "record", name: { text: "Bar" } },
                  },
                ],
              },
            },
          },
        },
        errors: [],
      });
    });

    it("resolves reference through import alias", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          import * as other from "./other";

          /// Uses [other.Foo]
          struct Bar {}
        `,
      );
      fakeFileReader.pathToCode.set(
        "path/to/root/other",
        `
          struct Foo {}
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Bar: {
              name: { text: "Bar" },
              doc: {
                pieces: [
                  { kind: "text", text: "Uses " },
                  {
                    kind: "reference",
                    nameParts: [
                      {
                        token: { text: "other" },
                        declaration: {
                          kind: "import-alias",
                          name: { text: "other" },
                        },
                      },
                      {
                        token: { text: "Foo" },
                        declaration: { kind: "record", name: { text: "Foo" } },
                      },
                    ],
                    referee: { kind: "record", name: { text: "Foo" } },
                  },
                ],
              },
            },
          },
        },
        errors: [{ message: "Unused import alias" }],
      });
    });

    it("resolves reference through import", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          import * as other from "./other";

          /// Uses [other.Foo]
          struct Bar {}
        `,
      );
      fakeFileReader.pathToCode.set(
        "path/to/root/other",
        `
          struct Foo {}
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Bar: {
              name: { text: "Bar" },
              doc: {
                pieces: [
                  { kind: "text", text: "Uses " },
                  {
                    kind: "reference",
                    nameParts: [
                      {
                        token: { text: "other" },
                        declaration: {
                          kind: "import-alias",
                          name: { text: "other" },
                        },
                      },
                      {
                        token: { text: "Foo" },
                        declaration: { kind: "record", name: { text: "Foo" } },
                      },
                    ],
                    referee: { kind: "record", name: { text: "Foo" } },
                  },
                ],
              },
            },
          },
        },
        errors: [{ message: "Unused import alias" }],
      });
    });

    it("reports error for unresolved reference", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          /// See [NonExistent]
          struct Foo {}
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {},
        errors: [
          {
            token: { text: "[NonExistent]", line: { lineNumber: 1 } },
            message: "Cannot resolve reference",
          },
        ],
      });
    });

    it("reports error for unresolved nested reference", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          /// See [Bar.NonExistent]
          struct Foo {}

          struct Bar {}
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {},
        errors: [
          {
            token: { text: "[Bar.NonExistent]" },
            message: "Cannot resolve reference",
          },
        ],
      });
    });

    it("prioritizes nested scope over module scope", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/module",
        `
          struct Outer {
            struct Inner {
              /// Reference to [Foo] (nested)
              x: int32;
            }
            struct Foo {}
          }

          struct Foo {}
        `,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("module");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Outer: {
              name: { text: "Outer" },
              nestedRecords: [
                {
                  name: { text: "Inner" },
                  fields: [
                    {
                      name: { text: "x" },
                      doc: {
                        pieces: [
                          { kind: "text", text: "Reference to " },
                          {
                            kind: "reference",
                            nameParts: [
                              {
                                token: { text: "Foo" },
                                declaration: {
                                  kind: "record",
                                  name: { text: "Foo" },
                                },
                              },
                            ],
                            // Should resolve to Outer.Foo, not the top-level Foo
                            referee: {
                              kind: "record",
                              name: { text: "Foo" },
                            },
                          },
                          { kind: "text", text: " (nested)" },
                        ],
                      },
                    },
                  ],
                },
                {
                  name: { text: "Foo" },
                },
              ],
            },
          },
        },
        errors: [],
      });
    });
  });

  describe("package prefixes", () => {
    it("package prefix extraction works", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/@my-org/my-package/bar",
        `struct Bar {}`,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("@my-org/my-package/bar");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Bar: {
              kind: "record",
            },
          },
        },
        errors: [],
      });
    });

    it("resolves absolute imports within same package", () => {
      const fakeFileReader = new FakeFileReader();
      const barCode = `struct Bar {}`;
      fakeFileReader.pathToCode.set(
        "path/to/root/@my-org/my-package/foo",
        `import Bar from "bar";

struct Foo {
  bar: Bar;
}`,
      );
      fakeFileReader.pathToCode.set(
        "path/to/root/@my-org/my-package/bar",
        barCode,
      );

      // Verify the bar code is what we expect
      const readBarCode = fakeFileReader.readTextFile(
        "path/to/root/@my-org/my-package/bar",
      );
      if (readBarCode !== barCode) {
        throw new Error(
          `Bar code mismatch: expected ${JSON.stringify(barCode)}, got ${JSON.stringify(readBarCode)}`,
        );
      }

      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("@my-org/my-package/foo");

      // First check that the import resolved correctly
      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Bar: {
              kind: "import",
              resolvedModulePath: "@my-org/my-package/bar",
            },
          },
        },
      });

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Bar: {
              kind: "import",
            },
            Foo: {
              kind: "record",
              fields: [
                {
                  name: { text: "bar" },
                  type: {
                    kind: "record",
                    key: "@my-org/my-package/bar:7",
                  },
                },
              ],
            },
          },
        },
        errors: [],
      });
    });

    it("does not apply package prefix to non-package modules", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/regular/module",
        `import Bar from "bar";

struct Foo {
  bar: Bar;
}`,
      );
      fakeFileReader.pathToCode.set("path/to/root/bar", `struct Bar {}`);
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("regular/module");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Bar: {
              kind: "import",
            },
            Foo: {
              kind: "record",
              fields: [
                {
                  name: { text: "bar" },
                  type: {
                    kind: "record",
                    key: "bar:7",
                  },
                },
              ],
            },
          },
        },
        errors: [],
      });
    });

    it("does not apply package prefix when import starts with @", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/@my-org/my-package/foo",
        `import Bar from "@other-org/other-package/bar";

struct Foo {
  bar: Bar;
}`,
      );
      fakeFileReader.pathToCode.set(
        "path/to/root/@other-org/other-package/bar",
        `struct Bar {}`,
      );
      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      const actual = moduleSet.parseAndResolve("@my-org/my-package/foo");

      expect(actual).toMatch({
        result: {
          nameToDeclaration: {
            Bar: {
              kind: "import",
            },
            Foo: {
              kind: "record",
              fields: [
                {
                  name: { text: "bar" },
                  type: {
                    kind: "record",
                    key: "@other-org/other-package/bar:7",
                  },
                },
              ],
            },
          },
        },
        errors: [],
      });
    });

    it("allows duplicate record numbers across packages", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/@my-org/pkg-a/module",
        `struct Foo(100) {}`,
      );
      fakeFileReader.pathToCode.set(
        "path/to/root/@my-org/pkg-b/module",
        `struct Bar(100) {}`,
      );

      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      {
        const actual = moduleSet.parseAndResolve("@my-org/pkg-a/module");
        expect(actual).toMatch({
          errors: [],
        });
      }
      {
        const actual = moduleSet.parseAndResolve("@my-org/pkg-b/module");
        expect(actual).toMatch({
          errors: [],
        });
      }
    });

    it("allows duplicate method numbers across packages", () => {
      const fakeFileReader = new FakeFileReader();
      fakeFileReader.pathToCode.set(
        "path/to/root/@my-org/pkg-a/module",
        `method GetFoo(string): string = 123;`,
      );
      fakeFileReader.pathToCode.set(
        "path/to/root/@my-org/pkg-b/module",
        `method GetBar(string): string = 123;`,
      );

      const moduleSet = ModuleSet.create(fakeFileReader, "path/to/root");
      {
        const actual = moduleSet.parseAndResolve("@my-org/pkg-a/module");
        expect(actual).toMatch({
          errors: [],
        });
      }
      {
        const actual = moduleSet.parseAndResolve("@my-org/pkg-b/module");
        expect(actual).toMatch({
          errors: [],
        });
      }
    });
  });

  describe("mergeFrom", () => {
    it("merges resolved modules list", () => {
      const moduleMap1 = new Map<string, string>();
      moduleMap1.set("module1", `struct Foo {}`);

      const moduleMap2 = new Map<string, string>();
      moduleMap2.set("module2", `struct Bar {}`);

      const moduleSet1 = ModuleSet.fromMap(moduleMap1);
      const moduleSet2 = ModuleSet.fromMap(moduleMap2);

      expect(moduleSet1.resolvedModules.length).toMatch(1);
      expect(moduleSet2.resolvedModules.length).toMatch(1);

      moduleSet1.mergeFrom(moduleSet2);

      expect(moduleSet1.resolvedModules.length).toMatch(2);
      expect(moduleSet1.resolvedModules[0]!.nameToDeclaration).toMatch({
        Foo: { kind: "record" },
      });
      expect(moduleSet1.resolvedModules[1]!.nameToDeclaration).toMatch({
        Bar: { kind: "record" },
      });
    });

    it("preserves record map after merge", () => {
      const moduleMap1 = new Map<string, string>();
      moduleMap1.set("module1", `struct Foo {}`);

      const moduleMap2 = new Map<string, string>();
      moduleMap2.set("module2", `struct Bar {}`);

      const moduleSet1 = ModuleSet.fromMap(moduleMap1);
      const moduleSet2 = ModuleSet.fromMap(moduleMap2);

      moduleSet1.mergeFrom(moduleSet2);

      const fooRecord = moduleSet1.recordMap.get("module1:7");
      expect(fooRecord).toMatch({
        record: {
          name: { text: "Foo" },
        },
      });

      const barRecord = moduleSet1.recordMap.get("module2:7");
      expect(barRecord).toMatch({
        record: {
          name: { text: "Bar" },
        },
      });
    });
  });
});
