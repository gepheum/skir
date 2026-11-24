import { expect } from "buckwheat";
import { describe, it } from "mocha";
import type { PathToImportedNames } from "skir-internal";
import { formatImportBlock } from "./import_block_formatter.js";

describe("formatImportBlock", () => {
  it("returns empty string for empty input", () => {
    expect(formatImportBlock({})).toMatch("");
  });

  it("formats a wildcard import", () => {
    const input: PathToImportedNames = {
      "foo/bar.skir": { kind: "all", alias: "bar" },
    };
    expect(formatImportBlock(input)).toMatch(
      `import * as bar from "foo/bar.skir";`,
    );
  });

  it("formats a single named import on one line", () => {
    const input: PathToImportedNames = {
      "foo/bar.skir": { kind: "some", names: new Set(["MyStruct"]) },
    };
    expect(formatImportBlock(input)).toMatch(
      `import { MyStruct } from "foo/bar.skir";`,
    );
  });

  it("formats multiple named imports sorted and multiline", () => {
    const input: PathToImportedNames = {
      "foo/bar.skir": {
        kind: "some",
        names: new Set(["Zebra", "Apple", "Mango"]),
      },
    };
    expect(formatImportBlock(input)).toMatch(
      `import {\n  Apple,\n  Mango,\n  Zebra,\n} from "foo/bar.skir";`,
    );
  });

  it("skips an import with zero names", () => {
    const input: PathToImportedNames = {
      "foo/bar.skir": { kind: "some", names: new Set() },
    };
    expect(formatImportBlock(input)).toMatch("");
  });

  it("sorts multiple imports alphabetically", () => {
    const input: PathToImportedNames = {
      "zoo/z.skir": { kind: "all", alias: "z" },
      "aaa/a.skir": { kind: "all", alias: "a" },
      "mmm/m.skir": { kind: "all", alias: "m" },
    };
    expect(formatImportBlock(input)).toMatch(
      [
        `import * as a from "aaa/a.skir";`,
        `import * as m from "mmm/m.skir";`,
        `import * as z from "zoo/z.skir";`,
      ].join("\n"),
    );
  });

  it("separates @-rooted imports from regular imports with a blank line", () => {
    const input: PathToImportedNames = {
      "local/foo.skir": { kind: "all", alias: "foo" },
      "@pkg/lib/bar.skir": { kind: "all", alias: "bar" },
    };
    expect(formatImportBlock(input)).toMatch(
      [
        `import * as bar from "@pkg/lib/bar.skir";`,
        ``,
        `import * as foo from "local/foo.skir";`,
      ].join("\n"),
    );
  });

  it("outputs only @-rooted imports when there are no regular ones", () => {
    const input: PathToImportedNames = {
      "@pkg/lib/bar.skir": { kind: "all", alias: "bar" },
    };
    expect(formatImportBlock(input)).toMatch(
      `import * as bar from "@pkg/lib/bar.skir";`,
    );
  });

  it("outputs only regular imports when there are no @-rooted ones", () => {
    const input: PathToImportedNames = {
      "local/foo.skir": { kind: "all", alias: "foo" },
    };
    expect(formatImportBlock(input)).toMatch(
      `import * as foo from "local/foo.skir";`,
    );
  });

  it("sorts @-rooted and regular imports each in their own group", () => {
    const input: PathToImportedNames = {
      "zzz/z.skir": { kind: "all", alias: "z" },
      "@b/lib/b.skir": { kind: "all", alias: "b" },
      "aaa/a.skir": { kind: "all", alias: "a" },
      "@a/lib/a.skir": { kind: "all", alias: "a2" },
    };
    expect(formatImportBlock(input)).toMatch(
      [
        `import * as a2 from "@a/lib/a.skir";`,
        `import * as b from "@b/lib/b.skir";`,
        ``,
        `import * as a from "aaa/a.skir";`,
        `import * as z from "zzz/z.skir";`,
      ].join("\n"),
    );
  });

  it("no blank line when all imports are @-rooted and some have zero names", () => {
    const input: PathToImportedNames = {
      "@pkg/lib/bar.skir": { kind: "some", names: new Set() },
      "@pkg/lib/foo.skir": { kind: "all", alias: "foo" },
    };
    expect(formatImportBlock(input)).toMatch(
      `import * as foo from "@pkg/lib/foo.skir";`,
    );
  });
});
