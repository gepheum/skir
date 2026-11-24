import type {
  JsonArray,
  JsonEdit,
  JsonError,
  JsonKey,
  JsonKeyValue,
  JsonObject,
  JsonParseResult,
  JsonValue,
  Segment,
} from "./types";

export function parseJsonValue(input: string): JsonParseResult {
  const tokens = tokenize(input);
  if (tokens.kind === "error") {
    return {
      value: undefined,
      errors: [tokens],
      edits: [],
    };
  }
  const parser = new JsonParser(tokens.tokens, input);
  const parseResult = parser.parseValueOrSkip();
  parser.expectEnd();

  return {
    value: parseResult,
    errors: parser.errors,
    edits: parser.edits,
  };
}

interface JsonToken {
  segment: Segment;
  jsonCode: string;
  indent: number;
}

interface JsonTokens {
  kind: "tokens";
  tokens: JsonToken[];
}

function tokenize(input: string): JsonTokens | JsonError {
  const tokens: JsonToken[] = [];
  let pos = 0;
  let lineIndent = 0;
  let lineHasContent = false;

  const whitespaceRegex = /[ \t\r\n]*/y;
  const tokenRegex =
    /([[\]{}:,]|(-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)|false|true|null|("(((?=\\)\\(["\\/ bfnrt]|u[0-9a-fA-F]{4}))|[^"\\\0-\x1F\x7F]+)*")|$)/y;

  while (true) {
    const beforeWhitespacePos = pos;
    whitespaceRegex.lastIndex = pos;
    whitespaceRegex.exec(input);
    pos = whitespaceRegex.lastIndex;

    for (let i = beforeWhitespacePos; i < pos; ++i) {
      const ch = input[i];
      if (ch === "\n") {
        lineIndent = 0;
        lineHasContent = false;
      } else if (!lineHasContent && (ch === " " || ch === "\t")) {
        lineIndent++;
      }
    }

    tokenRegex.lastIndex = pos;
    const tokenMatch = tokenRegex.exec(input);
    if (tokenMatch) {
      const tokenText = tokenMatch[0];
      const segment: Segment = {
        start: pos,
        end: pos + tokenText.length,
      };
      const token: JsonToken = {
        segment,
        jsonCode: tokenText,
        indent: lineIndent,
      };
      pos = tokenRegex.lastIndex;
      tokens.push(token);
      if (tokenText !== "") {
        lineHasContent = true;
      }
      if (tokenText === "") {
        return {
          kind: "tokens",
          tokens: tokens,
        };
      }
    } else {
      // Find the next word boundary using unicode support
      const wordBoundaryRegex = /\w*/uy;
      wordBoundaryRegex.lastIndex = pos + 1;
      wordBoundaryRegex.exec(input);
      const end = wordBoundaryRegex.lastIndex || pos + 1;
      return {
        kind: "error",
        message: "not a token",
        segment: { start: pos, end: end },
      };
    }
  }
}

class JsonParser {
  constructor(
    private tokens: JsonToken[],
    private readonly input: string,
  ) {}
  private tokenIndex = 0;
  errors: JsonError[] = [];
  edits: JsonEdit[] = [];
  private indent = "";

  parseValueOrSkip(): JsonValue | undefined {
    const token = this.peekToken();
    const firstChar = token.jsonCode ? token.jsonCode[0] : "";

    const { indent } = token;

    switch (firstChar) {
      case "[":
        return this.parseArray();
      case "{":
        return this.parseObject();
      case "n":
        this.nextToken();
        return {
          kind: "literal",
          firstToken: token.segment,
          segment: token.segment,
          jsonCode: "null",
          type: "null",
          indent,
        };
      case "f":
        this.nextToken();
        return {
          kind: "literal",
          firstToken: token.segment,
          segment: token.segment,
          jsonCode: "false",
          type: "boolean",
          indent,
        };
      case "t":
        this.nextToken();
        return {
          kind: "literal",
          firstToken: token.segment,
          segment: token.segment,
          jsonCode: "true",
          type: "boolean",
          indent,
        };
      case '"':
        this.nextToken();
        return {
          kind: "literal",
          firstToken: token.segment,
          segment: token.segment,
          jsonCode: token.jsonCode,
          type: "string",
          indent,
        };
      case "0":
      case "1":
      case "2":
      case "3":
      case "4":
      case "5":
      case "6":
      case "7":
      case "8":
      case "9":
      case "-":
        this.nextToken();
        return {
          kind: "literal",
          firstToken: token.segment,
          segment: token.segment,
          jsonCode: token.jsonCode,
          type: "number",
          indent,
        };
    }

    this.errors.push({
      kind: "error",
      message: "expected: value",
      segment: this.peekToken().segment,
    });
    this.skip();
    return undefined;
  }

  private parseArray(): JsonArray {
    const leftBracket = this.nextToken();
    const { indent } = leftBracket;
    const values: JsonValue[] = [];
    while (true) {
      if (this.peekToken().jsonCode === "]") {
        const rightBracket = this.nextToken();
        return {
          kind: "array",
          firstToken: leftBracket.segment,
          segment: {
            start: leftBracket.segment.start,
            end: rightBracket.segment.end,
          },
          values,
          indent,
        };
      }
      if (this.peekToken().jsonCode === "}") {
        this.errors.push({
          kind: "error",
          message: "expected: ']'",
          segment: this.peekToken().segment,
        });
        const wrongBracket = this.nextToken();
        return {
          kind: "array",
          firstToken: leftBracket.segment,
          segment: {
            start: leftBracket.segment.start,
            end: wrongBracket.segment.end,
          },
          values,
          indent,
        };
      }
      if (this.peekToken().jsonCode === "") {
        // End of file
        this.expectSymbolOrSkip("]");
        return {
          kind: "array",
          firstToken: leftBracket.segment,
          segment: {
            start: leftBracket.segment.start,
            end: this.peekToken().segment.start,
          },
          values,
          indent,
        };
      }
      const value = this.parseValueOrSkip();
      if (value) {
        values.push(value);
      }
      if (this.peekToken().jsonCode === ",") {
        const commaToken = this.nextToken();
        // Check if this is a trailing comma
        if (this.peekToken().jsonCode === "]") {
          // Trailing comma - add edit to remove it
          this.edits.push({
            segment: commaToken.segment,
            replacement: "",
          });
        }
      }
    }
  }

  private parseObject(): JsonObject {
    const leftBracket = this.nextToken();
    const { indent } = leftBracket;
    const keyValues: { [key: string]: JsonKeyValue } = {};
    const allKeys: JsonKey[] = [];
    while (true) {
      if (this.peekToken().jsonCode === "}") {
        const rightBracket = this.nextToken();
        return {
          kind: "object",
          firstToken: leftBracket.segment,
          segment: {
            start: leftBracket.segment.start,
            end: rightBracket.segment.end,
          },
          keyValues,
          allKeys,
          indent,
        };
      }
      if (this.peekToken().jsonCode === "]") {
        this.errors.push({
          kind: "error",
          message: "expected: ']'",
          segment: this.peekToken().segment,
        });
        const wrongBracket = this.nextToken();
        return {
          kind: "object",
          firstToken: leftBracket.segment,
          segment: {
            start: leftBracket.segment.start,
            end: wrongBracket.segment.end,
          },
          keyValues,
          allKeys,
          indent,
        };
      }
      if (this.peekToken().jsonCode === "") {
        // End of file
        this.expectSymbolOrSkip("}");
        return {
          kind: "object",
          firstToken: leftBracket.segment,
          segment: {
            start: leftBracket.segment.start,
            end: this.peekToken().segment.start,
          },
          keyValues,
          allKeys,
          indent,
        };
      }
      const keyToken = this.peekToken();
      if (!keyToken.jsonCode.startsWith('"')) {
        this.errors.push({
          kind: "error",
          message: "expected: string",
          segment: keyToken.segment,
        });
        this.skip();
        // Consume comma if we're stuck at one to avoid infinite loop
        if (this.peekToken().jsonCode === ",") {
          this.nextToken();
        }
        continue;
      }
      const key = JSON.parse(keyToken.jsonCode) as string;
      allKeys.push({
        key: key,
        keySegment: keyToken.segment,
      });
      this.nextToken();
      if (!this.expectSymbolOrSkip(":")) {
        continue;
      }
      if (keyValues[key]) {
        this.errors.push({
          kind: "error",
          message: "duplicate key",
          segment: keyToken.segment,
        });
      }
      const value = this.parseValueOrSkip();
      if (value) {
        keyValues[key] = {
          keySegment: keyToken.segment,
          key: key,
          value: value,
        };
      }
      if (this.peekToken().jsonCode === ",") {
        const commaToken = this.nextToken();
        // Check if this is a trailing comma
        if (this.peekToken().jsonCode === "}") {
          // Trailing comma - add edit to remove it
          this.edits.push({
            segment: commaToken.segment,
            replacement: "",
          });
        }
      }
    }
  }

  expectEnd(): void {
    const token = this.nextToken();
    if (token.jsonCode) {
      this.errors.push({
        kind: "error",
        message: "expected: end",
        segment: this.peekToken().segment,
      });
    }
  }

  private nextToken(): JsonToken {
    const result = this.tokens[this.tokenIndex];

    // Check the whitespace separator before the current token.
    {
      const previous =
        this.tokenIndex <= 0 ? undefined : this.tokens[this.tokenIndex - 1];
      const separatorSegment: Segment = {
        start: previous ? previous.segment.end : 0,
        end: result.segment.start,
      };
      const actualSeparator = this.input.substring(
        separatorSegment.start,
        separatorSegment.end,
      );
      const expectedSeparator = this.inferWhitespaceSeparator(
        previous?.jsonCode ?? "",
        result.jsonCode,
      );

      if (actualSeparator !== expectedSeparator.text) {
        this.edits.push({
          segment: separatorSegment,
          replacement: expectedSeparator.text,
        });
      }
      this.indent = expectedSeparator.newIndent ?? this.indent;
    }

    ++this.tokenIndex;
    return result;
  }

  private inferWhitespaceSeparator(a: string, b: string): WhitespaceSeparator {
    const { indent } = this;
    if (a === ":") {
      return {
        text: " ",
      };
    } else if (a === "," && b !== "]" && b !== "}") {
      return {
        text: `\n${indent}`,
      };
    } else if (/[0-9"}\]el]$/.test(a) && /^[0-9"{[tfn-]/.test(b)) {
      // a is the end of a JSON value and B is the start of a JSON value
      return {
        text: `,\n${indent}`,
      };
    } else if ((a === "[" && b !== "]") || (a === "{" && b !== "}")) {
      const newIndent = indent + INDENT_UNIT;
      return {
        text: `\n${newIndent}`,
        newIndent: newIndent,
      };
    } else if ((a !== "[" && b === "]") || (a !== "{" && b === "}")) {
      const newIndent = indent.replace(INDENT_UNIT, "");
      return {
        text: `\n${newIndent}`,
        newIndent: newIndent,
      };
    } else {
      return {
        text: "",
      };
    }
  }

  private peekToken(): JsonToken {
    return this.tokens[this.tokenIndex];
  }

  private expectSymbolOrSkip(symbol: string): boolean {
    if (this.peekToken().jsonCode !== symbol) {
      this.errors.push({
        kind: "error",
        message: `expected: '${symbol}'`,
        segment: this.peekToken().segment,
      });
      this.skip();
      return false;
    }
    this.nextToken();
    return true;
  }

  private skip(): void {
    while (true) {
      const tokenJson = this.peekToken().jsonCode;
      if (
        tokenJson === "" ||
        tokenJson === "," ||
        tokenJson === "]" ||
        tokenJson === "}" ||
        tokenJson.startsWith('"')
      ) {
        return;
      } else if (tokenJson === "[") {
        this.parseArray();
      } else if (tokenJson === "{") {
        this.parseObject();
      } else {
        this.nextToken();
      }
    }
  }
}

/// Text to insert between two consecutive tokens.
interface WhitespaceSeparator {
  /// Matches /(,?)(\n?)( )*/
  text: string;
  newIndent?: string;
}

const INDENT_UNIT = "  ";
