import { assert } from "node:console";
import type {
  Doc,
  DocPiece,
  DocReference,
  DocReferenceName,
  MutableDoc,
  MutableDocPiece,
  MutableDocReferenceName,
  Result,
  SkirError,
  Token,
} from "skir-internal";

export function parseDocComment(docComment: Token): Result<Doc> {
  const parser = new DocCommentParser(docComment);
  return parser.parse();
}

class DocCommentParser {
  private readonly pieces: DocPiece[] = [];
  private readonly errors: SkirError[] = [];
  private currentText = "";
  private charIndex = -1;
  private readonly content: string;

  constructor(private readonly docComment: Token) {
    const { text } = docComment;
    if (text.startsWith("/// ")) {
      this.content = text.slice(4);
    } else if (text.startsWith("///")) {
      this.content = text.slice(3);
    } else {
      throw new Error("Expected doc comment to start with ///");
    }
    this.charIndex = 0;
  }

  parse(): Result<Doc> {
    this.parseDocComment();

    // Add any remaining text
    if (this.currentText.length > 0) {
      this.pieces.push({ kind: "text", text: this.currentText });
    }

    const { pieces } = this;
    const text = pieces
      .map((p) => {
        switch (p.kind) {
          case "text":
            return p.text;
          case "reference":
            return p.referenceRange.text;
        }
      })
      .join("");

    return {
      result: {
        text: text,
        pieces: this.pieces,
      },
      errors: this.errors,
    };
  }

  private parseDocComment(): void {
    // Matches unescaped [ or ], OR escaped [[ or ]]
    const specialCharRegex = /\[\[|\]\]|\[|\]/g;

    while (this.charIndex < this.content.length) {
      // Find next special character or escaped bracket
      specialCharRegex.lastIndex = this.charIndex;
      const match = specialCharRegex.exec(this.content);

      if (!match) {
        // No more special characters, add rest as text
        this.currentText += this.content.slice(this.charIndex);
        break;
      }

      // Add text before the special character
      if (match.index > this.charIndex) {
        this.currentText += this.content.slice(this.charIndex, match.index);
      }

      const matched = match[0];
      this.charIndex = match.index;

      if (matched === "[[") {
        // Escaped left bracket
        this.currentText += "[";
        this.charIndex += 2;
      } else if (matched === "]]") {
        // Escaped right bracket
        this.currentText += "]";
        this.charIndex += 2;
      } else if (matched === "[") {
        // Start of a reference - save current text if any
        if (this.currentText.length > 0) {
          this.pieces.push({ kind: "text", text: this.currentText });
          this.currentText = "";
        }

        // Parse the reference
        const reference = this.parseReference();
        this.pieces.push(reference);
      } else if (matched === "]") {
        // Unmatched right bracket - treat as text
        this.currentText += matched;
        this.charIndex++;
      }
    }
  }

  private parseReference(): DocReference {
    const { content, docComment } = this;

    const leftBracketCharIndex = this.charIndex;
    const contentOffset = docComment.text.length - content.length;
    const startPosition =
      docComment.position + contentOffset + leftBracketCharIndex;

    const rightBracketCharIndex = content.indexOf("]", leftBracketCharIndex);

    // End position: right after the closing bracket or at end of the line if
    // not found.
    const endCharIndex =
      rightBracketCharIndex < 0 ? content.length : rightBracketCharIndex + 1;

    const referenceText = content.slice(leftBracketCharIndex, endCharIndex);
    const referenceRange: Token = {
      text: referenceText,
      originalText: referenceText,
      position: startPosition,
      line: docComment.line,
      colNumber: startPosition - docComment.line.position,
    };

    let hasError = false;
    if (rightBracketCharIndex < 0) {
      hasError = true;
      this.errors.push({
        token: referenceRange,
        message: "Unterminated reference",
      });
    }

    // Move past the left bracket
    this.charIndex++;

    const wordRegex = /[a-zA-Z][_a-zA-Z0-9]*/g;

    const tokens: Token[] = [];
    while (this.charIndex < endCharIndex) {
      const char = content[this.charIndex]!;
      const contentOffset = docComment.text.length - content.length;
      const position = docComment.position + contentOffset + this.charIndex;

      const makeToken = (text: string): Token => ({
        text: text,
        originalText: text,
        position: position,
        line: docComment.line,
        colNumber: position - docComment.line.position,
      });

      if (char === ".") {
        // Dot token
        tokens.push(makeToken("."));
        this.charIndex++;
      } else if (/^[a-zA-Z]/.test(char)) {
        // Start of a word token - use regex to match the whole word
        wordRegex.lastIndex = this.charIndex;
        const match = wordRegex.exec(content);
        const word = match![0];
        tokens.push(makeToken(word));
        this.charIndex += word.length;
      } else if (char === "]") {
        // Reached the end of the reference
        tokens.push(makeToken("]"));
        this.charIndex++;
      } else {
        // Invalid character in reference (including whitespace)
        const contentOffset = docComment.text.length - content.length;
        const column =
          this.docComment.colNumber + contentOffset + this.charIndex;
        hasError = true;
        this.errors.push({
          token: referenceRange,
          message: `Invalid character in reference at column ${column + 1}`,
        });
        // Exit loop
        this.charIndex = endCharIndex;
      }
    }

    const nameParts = hasError ? [] : this.parseNameParts(tokens);

    return {
      kind: "reference",
      nameParts: nameParts,
      absolute: tokens[0]?.text === ".",
      referee: undefined,
      docComment: this.docComment,
      referenceRange: referenceRange,
    };
  }

  private parseNameParts(
    tokens: readonly Token[],
  ): readonly DocReferenceName[] {
    const nameParts: MutableDocReferenceName[] = [];
    let expect: "identifier" | "identifier or '.'" | "'.' or ']'" =
      "identifier or '.'";
    for (const token of tokens) {
      let expected: boolean;
      if (/^[a-zA-Z]/.test(token.text)) {
        expected = expect === "identifier or '.'" || expect === "identifier";
        expect = "'.' or ']'";
        nameParts.push({
          token: token,
          declaration: undefined,
        });
      } else if (token.text === ".") {
        expected = expect === "identifier or '.'" || expect === "'.' or ']'";
        expect = "identifier";
      } else {
        assert(token.text === "]");
        expected = expect === "'.' or ']'";
      }
      if (!expected) {
        this.errors.push({
          token: token,
          expected: expect,
        });
        return [];
      }
      if (token.text === "]") {
        return nameParts;
      }
    }
    // An error has already been pushed to signify the unterminated reference.
    return [];
  }
}

export function mergeDocs(docs: readonly Doc[]): MutableDoc {
  if (docs.length <= 0) {
    return EMPTY_DOC;
  }
  // Insert '\n' between each doc comment (== line)
  const text = docs.map((d) => d.text).join("\n");
  const pieces: MutableDocPiece[] = [];
  for (let i = 0; i < docs.length; ++i) {
    const doc = docs[i]!;
    if (i !== 0) {
      pieces.push({
        kind: "text",
        text: "\n",
      });
    }
    doc.pieces.forEach((p) => pieces.push(p));
  }
  return {
    text: text,
    pieces: pieces,
  };
}

const EMPTY_DOC: Doc = {
  text: "",
  pieces: [],
};
