import { expect } from "buckwheat";
import { describe, it } from "mocha";
import type { CodeLine, Token } from "skir-internal";
import { parseDocComment } from "./doc_comment_parser.js";

function makeToken(text: string, position: number = 0): Token {
  const line: CodeLine = {
    lineNumber: 0,
    line: text,
    position: 0,
    modulePath: "test",
  };
  return {
    text,
    originalText: text,
    position,
    line,
    colNumber: 0,
  };
}

describe("doc_comment_parser", () => {
  it("parses simple text", () => {
    const token = makeToken("/// Hello, world!");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [{ kind: "text", text: "Hello, world!" }],
      },
    });
  });

  it("skips exactly one space after ///", () => {
    const token1 = makeToken("/// Hello");
    const result1 = parseDocComment(token1);
    expect(result1).toMatch({
      errors: [],
      result: {
        text: "Hello",
        pieces: [{ kind: "text", text: "Hello" }],
      },
    });

    const token2 = makeToken("///  Two spaces");
    const result2 = parseDocComment(token2);
    expect(result2).toMatch({
      errors: [],
      result: {
        text: " Two spaces",
        pieces: [{ kind: "text", text: " Two spaces" }],
      },
    });

    const token3 = makeToken("///No space");
    const result3 = parseDocComment(token3);
    expect(result3).toMatch({
      errors: [],
      result: {
        text: "No space",
        pieces: [{ kind: "text", text: "No space" }],
      },
    });
  });

  it("parses simple reference", () => {
    const token = makeToken("/// See [.foo.Bar] for details");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [],
      result: {
        text: "See [.foo.Bar] for details",
        pieces: [
          { kind: "text", text: "See " },
          {
            kind: "reference",
            nameParts: [{ token: { text: "foo" } }, { token: { text: "Bar" } }],
            absolute: true,
          },
          { kind: "text", text: " for details" },
        ],
      },
    });
  });

  it("parses reference without leading dot", () => {
    const token = makeToken("/// See [Foo] for details");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [
          {},
          {
            kind: "reference",
            nameParts: [{ token: { text: "Foo" } }],
            absolute: false,
          },
          {},
        ],
      },
    });
  });

  it("rejects reference with whitespace", () => {
    const token = makeToken("/// See [ .foo ] for details");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [
        {
          token: {
            text: "[ .foo ]",
          },
          message: "Invalid character in reference at column 10",
        },
      ],
    });
  });

  it("parses escaped brackets", () => {
    const token = makeToken("/// Hello [[world]]!");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [{ kind: "text", text: "Hello [world]!" }],
      },
    });
  });

  it("handles unmatched closing bracket", () => {
    const token = makeToken("/// Hello ] world");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [{ kind: "text", text: "Hello ] world" }],
      },
    });
  });

  it("parses multiple references and text fragments", () => {
    const token = makeToken("/// world [.foo.Bar], how are you?");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [
          { kind: "text", text: "world " },
          { kind: "reference" },
          { kind: "text", text: ", how are you?" },
        ],
      },
    });
  });

  it("reports error for empty reference", () => {
    const token = makeToken("/// See [] for details");
    const result = parseDocComment(token);

    expect(result).toMatch({
      result: {},
      errors: [
        {
          token: {
            text: "]",
          },
          expected: "identifier or '.'",
        },
      ],
    });
  });

  it("reports error for unterminated reference", () => {
    const token = makeToken("/// See [.foo.Bar");
    const result = parseDocComment(token);

    expect(result).toMatch({
      result: {
        pieces: [
          { kind: "text", text: "See " },
          { kind: "reference", nameParts: [], absolute: true },
        ],
      },
      errors: [{ message: "Unterminated reference" }],
    });
  });

  it("reports error for invalid character in reference", () => {
    const token = makeToken("/// See [foo@bar] for details");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [
        {
          token: {
            text: "[foo@bar]",
          },
          message: "Invalid character in reference at column 13",
        },
      ],
    });
  });

  it("rejects digit at start of word in reference", () => {
    const token = makeToken("/// See [.foo.9Bar] for details");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [
        {
          token: {
            text: "[.foo.9Bar]",
          },
          message: "Invalid character in reference at column 15",
        },
      ],
    });
  });

  it("allows underscore and digits in word after first letter", () => {
    const token = makeToken("/// See [Foo_Bar_123] for details");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [
          {},
          {
            kind: "reference",
            nameParts: [{ token: { text: "Foo_Bar_123" } }],
            absolute: false,
          },
          {},
        ],
      },
    });
  });

  it("handles mixed escaped brackets and references", () => {
    const token = makeToken("/// [[Not a reference]] but [RealReference] is");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [
          { kind: "text", text: "[Not a reference] but " },
          { kind: "reference" },
          { kind: "text", text: " is" },
        ],
      },
    });
  });

  it("handles only whitespace after ///", () => {
    const token = makeToken("///   ");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [{ kind: "text", text: "  " }],
      },
    });
  });

  it("continues parsing after error", () => {
    const token = makeToken("/// Invalid [@] here and [..] here.");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [
        {
          token: {
            text: "[@]",
          },
          message: "Invalid character in reference at column 14",
        },
        {
          token: {
            text: ".",
          },
          expected: "identifier",
        },
      ],
    });
  });

  it("handles reference at start of comment", () => {
    const token = makeToken("///[Reference] at start");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [{ kind: "reference" }, { kind: "text", text: " at start" }],
      },
    });
  });

  it("handles reference at end of comment", () => {
    const token = makeToken("/// End with [Reference]");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [{ kind: "text", text: "End with " }, { kind: "reference" }],
      },
    });
  });

  it("handles consecutive references", () => {
    const token = makeToken("/// [Ref1][Ref2][Ref3]");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [
          { kind: "reference" },
          { kind: "reference" },
          { kind: "reference" },
        ],
      },
    });
  });

  it("preserves correct token positions with space after ///", () => {
    const token = makeToken("/// [Foo]", 100);
    const result = parseDocComment(token);

    // Position should be 100 (start) + 3 (///) + 1 (space) + 1 (opening bracket) = 105
    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [
          {
            kind: "reference",
            nameParts: [{ token: { text: "Foo", position: 105 } }],
            absolute: false,
          },
        ],
      },
    });
  });

  it("preserves correct token positions without space after ///", () => {
    const token = makeToken("///[Foo]", 100);
    const result = parseDocComment(token);

    // Position should be 100 (start) + 3 (///) + 1 (opening bracket) = 104
    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [
          {
            kind: "reference",
            nameParts: [{ token: { text: "Foo", position: 104 } }],
            absolute: false,
          },
        ],
      },
    });
  });

  it("preserves correct error positions with space after ///", () => {
    const token = makeToken("/// [@invalid]", 100);
    const result = parseDocComment(token);

    // Error should be at position 100 + 3 (///) + 1 (space) = 104
    expect(result).toMatch({
      errors: [
        {
          token: {
            text: "[@invalid]",
            position: 104,
          },
        },
      ],
    });
  });

  it("preserves correct error positions without space after ///", () => {
    const token = makeToken("///[@invalid]", 100);
    const result = parseDocComment(token);

    // Error should be at position 100 + 3 (///) = 103
    expect(result).toMatch({
      errors: [
        {
          token: {
            text: "[@invalid]",
            position: 103,
          },
        },
      ],
    });
  });

  it("reports error for unterminated reference at end of line", () => {
    const token = makeToken("/// See [.foo.Bar");
    const result = parseDocComment(token);

    expect(result).toMatch({
      result: {},
      errors: [{ message: "Unterminated reference" }],
    });
  });

  it("sets docComment field in reference", () => {
    const token = makeToken("/// See [Foo] here");
    const result = parseDocComment(token);

    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [
          {},
          {
            kind: "reference",
            docComment: token,
          },
          {},
        ],
      },
    });
  });

  it("sets referenceRange field to include brackets", () => {
    const token = makeToken("/// See [.foo.Bar] here", 100);
    const result = parseDocComment(token);

    // Position: 100 (start) + 4 (/// ) + 4 (See ) = 108
    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [
          {},
          {
            kind: "reference",
            referenceRange: {
              text: "[.foo.Bar]",
              originalText: "[.foo.Bar]",
              position: 108,
              colNumber: 108,
            },
          },
          {},
        ],
      },
    });
  });

  it("referenceRange works without space after ///", () => {
    const token = makeToken("///[Foo]", 50);
    const result = parseDocComment(token);

    // Position: 50 (start) + 3 (///) = 53
    expect(result).toMatch({
      errors: [],
      result: {
        pieces: [
          {
            kind: "reference",
            referenceRange: {
              text: "[Foo]",
              position: 53,
            },
          },
        ],
      },
    });
  });
});
