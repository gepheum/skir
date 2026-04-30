import type {
  Declaration,
  Doc,
  Module,
  Range,
  Record,
  SkirError,
  Token,
  Value,
} from "skir-internal";
import { formatImportBlock } from "./import_block_formatter.js";
import { parseModule } from "./parser.js";
import { ModuleTokens, tokenizeModule } from "./tokenizer.js";

export interface FormattedModule {
  readonly newSourceCode: string;
  /**
   * For VSCode extension: text edits to convert the original source code into
   * the formatted source code.
   */
  readonly textEdits: readonly TextEdit[];

  /**
   * Tokenization and parsing errors.
   * If there is any error, the original source code is returned and no text edits are
   * provided.
   */
  readonly errors: readonly SkirError[];
}

export interface TextEdit {
  readonly oldStart: number;
  readonly oldEnd: number;
  readonly newText: string;
}

/** A function which returns a random number between 0 and 1. */
export type RandomGenerator = () => number;

/**
 * Formats the given module and returns the new source code.
 * If a resolved module is provided, the formatter will try to convert enum
 * variants spelled with the legacy UPPERCASE format to the preferred lowercase
 * format.
 */
export function formatModule(args: {
  sourceCode: string;
  modulePath: string;
  resolvedModule?: Module;
  randomGenerator?: RandomGenerator;
}): FormattedModule {
  const { modulePath, resolvedModule, randomGenerator = Math.random } = args;
  let { sourceCode } = args;

  const makeErroredResult = (
    errors: readonly SkirError[],
  ): FormattedModule => ({
    newSourceCode: sourceCode,
    textEdits: [],
    errors: errors,
  });

  if (resolvedModule) {
    if (resolvedModule.sourceCode !== sourceCode) {
      throw new Error(
        "Resolved module's source code does not match the provided source code.",
      );
    }
    sourceCode = convertLegacyVariantNames(resolvedModule).newSourceCode;
  }

  const moduleTokens = tokenizeModule(sourceCode, modulePath);
  if (moduleTokens.errors.length > 0) {
    return makeErroredResult(moduleTokens.errors);
  }

  const module = parseModule(moduleTokens.result, "lenient");
  if (module.errors.length > 0) {
    return makeErroredResult(module.errors);
  }

  const blocks = getBlocks(moduleTokens.result, module.result);

  const context: Context = {
    context: null,
    indentStack: [{ indent: "" }],
  };

  let newSourceCode = "";
  const textEdits: TextEdit[] = [];
  let lastNonCommentToken = "";

  const appendBlock = (block: Block): void => {
    if (block.kind === "import-block") {
      if (block.newBlock !== block.oldBlock) {
        textEdits.push({
          oldStart: block.oldRange.start,
          oldEnd: block.oldRange.end,
          newText: block.newBlock,
        });
      }
      newSourceCode += block.newBlock;
    } else {
      const { token } = block;
      const newToken = normalizeToken(
        token.text,
        lastNonCommentToken,
        randomGenerator,
      );
      if (newToken !== token.text) {
        textEdits.push({
          oldStart: token.position,
          oldEnd: token.position + token.text.length,
          newText: newToken,
        });
      }
      if (!isComment(token)) {
        lastNonCommentToken = token.text;
      }
      newSourceCode += newToken;
    }
  };
  {
    const firstBlock = blocks[0]!;
    const firstBlockStart = getStartPosition(firstBlock);
    if (firstBlockStart > 0) {
      textEdits.push({
        oldStart: 0,
        oldEnd: firstBlockStart,
        newText: "",
      });
    }
    appendBlock(firstBlock);
  }

  for (let i = 1; i < blocks.length; i++) {
    const block = blocks[i - 1]!;
    const next = blocks[i]!;

    // Find the next non-comment block
    let nextNonComment = next;
    for (let j = i; j < blocks.length; j++) {
      const block = blocks[j]!;
      if (!blockIsComment(block)) {
        nextNonComment = block;
        break;
      }
    }

    // Determine the text to add after 'block' and before 'next': a possible
    // trailing comma followed by whitespace.
    let newSeparator = shouldAddTrailingComma(block, nextNonComment!, context)
      ? ","
      : "";
    newSeparator += getWhitespaceAfterBlock(
      block,
      next,
      nextNonComment!,
      context,
    );
    const topOfStack = context.indentStack.at(-1)!;
    if (newSeparator.endsWith("\n")) {
      newSeparator = newSeparator + topOfStack.indent;
    }

    const oldSeparator = sourceCode.slice(
      getEndPosition(block),
      getStartPosition(next),
    );
    if (oldSeparator !== newSeparator) {
      textEdits.push({
        oldStart: getEndPosition(block),
        oldEnd: getStartPosition(next),
        newText: newSeparator,
      });
    }

    newSourceCode += newSeparator;

    appendBlock(next);
  }

  return {
    newSourceCode: newSourceCode,
    textEdits: textEdits,
    errors: [],
  };
}

type Block =
  | {
      kind: "token";
      token: Token;
    }
  | {
      kind: "import-block";
      newBlock: string;
      oldBlock: string;
      oldRange: Range;
    };

function getBlocks(
  moduleTokens: ModuleTokens,
  module: Module,
): readonly Block[] {
  const blocks = moduleTokens.tokensWithComments.map(
    (t): Block => ({ kind: "token", token: t }),
  );
  const { importBlockRange } = module;
  if (!importBlockRange) {
    // No import block.
    return blocks;
  }
  const importBlock: Block = {
    kind: "import-block",
    newBlock: formatImportBlock(module.pathToImportedNames),
    oldBlock: module.sourceCode.slice(
      importBlockRange.start,
      importBlockRange.end,
    ),
    oldRange: importBlockRange,
  };
  // Index of the first token in the import block.
  const importTokenIndex = blocks.findIndex(
    (t) => t.kind === "token" && t.token.position >= importBlockRange.start,
  );
  // Number of tokens in the import block.
  const importTokenCount = blocks
    .slice(importTokenIndex)
    .findIndex(
      (t) => t.kind === "token" && t.token.position >= importBlockRange.end,
    );
  // Replace the tokens in the import block with a single "import-block" block.
  blocks.splice(importTokenIndex, importTokenCount, importBlock);
  return blocks;
}

type Context = {
  context:
    | "const" // Between 'const' and '='
    | "in-value" // After 'const', between '=' and ';'
    | "removed" // Between 'removed' and ';'
    | "import" // Between 'import' and ';'
    | null;
  readonly indentStack: IndentStackItem[];
};

interface IndentStackItem {
  indent: string;
  methodRequest?: true;
}

function getWhitespaceAfterBlock(
  block: Block,
  nextBlock: Block,
  // If 'next' is a comment, the next non-comment block after 'next'.
  // Otherwise, 'next' itself.
  nextNonComment: Block,
  context: Context,
): "" | " " | "  " | "\n" | "\n\n" {
  if (block.kind === "import-block" || nextBlock.kind === "import-block") {
    return "\n\n";
  }

  const token = block.token;
  const next = nextBlock.token;

  const topOfStack = (): IndentStackItem => context.indentStack.at(-1)!;

  const indentUnit = "  ";
  if (
    token.text === "{" ||
    token.text === "{|" ||
    (context.context === "in-value" && token.text === "[")
  ) {
    context.indentStack.push({
      indent: topOfStack().indent + indentUnit,
    });
  } else if (token.text === "(" && !isNumberOrQuestionMark(nextNonComment)) {
    context.indentStack.push({
      indent: topOfStack().indent + indentUnit,
      methodRequest: true,
    });
  }

  let dedent: true | undefined;
  if (
    next.text === "}" ||
    next.text === "|}" ||
    (context.context === "in-value" && next.text === "]") ||
    (next.text === ")" && topOfStack().methodRequest)
  ) {
    context.indentStack.pop();
    dedent = true;
  }

  // Reset context when we encounter a semicolon, even if the next token is a
  // comment. Without this, the "in-value" context from a const declaration
  // leaks past comments and into subsequent declarations, causing spurious
  // trailing commas.
  if (token.text === ";") {
    context.context = null;
  }

  if (isComment(token)) {
    return oneOrTwoLineBreaks(token, next);
  } else if (
    token.text !== "{" &&
    next.text === "}" &&
    context.context !== "in-value"
  ) {
    return "\n";
  } else if (next.text === ")" && dedent) {
    return "\n";
  } else if (isComment(next)) {
    return token.line.lineNumber === next.line.lineNumber
      ? "  "
      : oneOrTwoLineBreaks(token, next);
  } else if (next.text === "=") {
    return " ";
  } else if (
    (token.text === "[" && next.text === "]") ||
    (token.text === "{" && next.text === "}") ||
    (token.text === "{|" && next.text === "|}")
  ) {
    return "";
  } else if (["{", "{|"].includes(token.text)) {
    return "\n";
  } else if (token.text === "[") {
    return context.context === "in-value" ? "\n" : "";
  } else if (["*", ":"].includes(token.text)) {
    return " ";
  } else if (token.text === "(") {
    return isNumberOrQuestionMark(nextNonComment) ? "" : "\n";
  } else if (token.text === ")") {
    return next.text === "{" ? " " : "";
  } else if (token.text === ";") {
    return oneOrTwoLineBreaks(token, next);
  } else if (token.text === "}") {
    return [",", ";"].includes(next.text)
      ? ""
      : oneOrTwoLineBreaks(token, next);
  } else if (token.text === ",") {
    return context.context === "removed" || context.context === "import"
      ? " "
      : "\n";
  } else if (token.text === "=") {
    if (context.context === "const") {
      context.context = "in-value";
    }
    return " ";
  } else if (token.text === "const") {
    context.context = "const";
    return " ";
  } else if (token.text === "removed") {
    context.context = "removed";
    return next.text === ";" ? "" : " ";
  } else if (token.text === "import") {
    context.context = "import";
    return " ";
  } else if (
    context.context === "in-value" &&
    ["]", "}", "|}"].includes(next.text)
  ) {
    return "\n";
  } else if (
    /^[A-Za-z]/.test(token.text) &&
    !["(", ":", ",", ";", "|", ".", ")", "]", "?"].includes(next.text)
  ) {
    return " ";
  } else {
    return "";
  }
}

function shouldAddTrailingComma(
  first: Block,
  nextNonComment: Block,
  context: Context,
): boolean {
  return (
    first.kind !== "import-block" &&
    nextNonComment.kind !== "import-block" &&
    context.context === "in-value" &&
    ["]", "}", "|}"].includes(nextNonComment.token.text) &&
    !["[", "{", "{|", ","].includes(first.token.text)
  );
}

function oneOrTwoLineBreaks(first: Token, second: Token): "\n" | "\n\n" {
  const firstLineNumber =
    first.line.lineNumber + first.text.split("\n").length - 1;
  if (
    firstLineNumber < second.line.lineNumber - 1 &&
    (isComment(second) || /^[A-Za-z]/.test(second.text))
  ) {
    return "\n\n";
  } else {
    return "\n";
  }
}

function isComment(token: Token): boolean {
  return token.text.startsWith("//") || token.text.startsWith("/*");
}

function blockIsComment(block: Block): boolean {
  return block.kind === "token" && isComment(block.token);
}

function isNumberOrQuestionMark(block: Block): boolean {
  return block.kind === "token" && /^[?0-9]/.test(block.token.text);
}

function getStartPosition(block: Block): number {
  if (block.kind === "import-block") {
    return block.oldRange.start;
  } else {
    return block.token.position;
  }
}

function getEndPosition(block: Block): number {
  if (block.kind === "import-block") {
    return block.oldRange.end;
  } else {
    const { token } = block;
    return token.position + token.text.length;
  }
}

function normalizeToken(
  token: string,
  lastNonCommentToken: string,
  randomGenerator: RandomGenerator,
): string {
  if (token.startsWith("//")) {
    // Make sure there is a space between the double slash and the comment text.
    if (
      token.startsWith("// ") ||
      token.startsWith("/// ") ||
      token === "//" ||
      token === "///"
    ) {
      return token;
    } else if (token.startsWith("///")) {
      return "/// " + token.slice(3);
    } else {
      return "// " + token.slice(2);
    }
  } else if (token.startsWith("'")) {
    // A single-quoted string
    if (token.includes('"')) {
      // Remove escape characters before single quotes.
      return token.replace(/\\(?=(?:\\\\)*')/g, "");
    } else {
      // If the string does not contain double quotes, turn it into a
      // double-quoted string for consistency
      const content = token.slice(1, -1);
      // Remove escape characters before double quotes.
      return '"' + content.replace(/\\(?=(?:\\\\)*")/g, "") + '"';
    }
  } else if (token.startsWith('"')) {
    // A double-quoted string
    // Remove escape characters before double quotes.
    return token.replace(/\\(?=(?:\\\\)*')/g, "");
  } else if (token === "?" && ["=", "("].includes(lastNonCommentToken)) {
    const randomNumber = Math.floor(randomGenerator() * 1_000_000);
    return String(randomNumber);
  } else {
    return token;
  }
}

/**
 * Converts the constant variants spelled with the legacy UPPERCASE format to
 * the preferred lowercase format.
 * The enum must not be declared in an external dependency.
 */
function convertLegacyVariantNames(resolvedModule: Module): {
  newSourceCode: string;
} {
  const legacyTokens: Token[] = [];
  const isEligibleEnum = (record: Record): boolean =>
    record.recordType === "enum" &&
    !record.name.line.modulePath.startsWith("@");
  const collectInDoc = (doc: Doc): void => {
    for (const piece of doc.pieces) {
      if (piece.kind !== "reference") continue;
      const { referee } = piece;
      if (
        referee?.kind === "field" &&
        !referee.field.unresolvedType &&
        isEligibleEnum(referee.record) &&
        /^[A-Z]/.test(referee.field.name.text)
      ) {
        const { token } = piece.nameParts.at(-1)!;
        legacyTokens.push(token);
      }
    }
  };
  const collectInValue = (value: Value): void => {
    switch (value.kind) {
      case "array": {
        return value.items.forEach(collectInValue);
      }
      case "object": {
        return Object.values(value.entries).forEach((val) => {
          collectInValue(val.value);
        });
      }
      case "literal": {
        if (
          value.type &&
          value.type.kind === "enum" &&
          isEligibleEnum(value.type.enum) &&
          /^['"][A-Z]/.test(value.token.text)
        ) {
          legacyTokens.push(value.token);
        }
      }
    }
  };
  const collect = (declaration: Declaration, inEligibleEnum: boolean): void => {
    // First, collect tokens from doc references.
    switch (declaration.kind) {
      case "constant":
      case "field":
      case "method":
      case "record": {
        collectInDoc(declaration.doc);
      }
    }
    switch (declaration.kind) {
      case "constant": {
        return collectInValue(declaration.value);
      }
      case "field": {
        if (
          inEligibleEnum &&
          !declaration.unresolvedType &&
          /^[A-Z]/.test(declaration.name.text)
        ) {
          legacyTokens.push(declaration.name);
        }
        break;
      }
      case "record": {
        const isEligible = isEligibleEnum(declaration);
        declaration.declarations.forEach((decl) => collect(decl, isEligible));
      }
    }
  };
  for (const declaration of resolvedModule.declarations) {
    const inEligibleEnum = false;
    collect(declaration, inEligibleEnum);
  }

  const oldSourceCode = resolvedModule.sourceCode;
  if (legacyTokens.length === 0) {
    return { newSourceCode: oldSourceCode };
  }
  legacyTokens.sort((a, b) => a.position - b.position);

  const fragments: string[] = [];
  let lastPosition = 0;
  for (const legacyToken of legacyTokens) {
    fragments.push(oldSourceCode.slice(lastPosition, legacyToken.position));
    fragments.push(legacyToken.text.toLowerCase());
    lastPosition = legacyToken.position + legacyToken.text.length;
  }
  fragments.push(oldSourceCode.slice(lastPosition));
  return {
    newSourceCode: fragments.join(""),
  };
}
