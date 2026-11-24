import type {
  Doc,
  ExpectedName,
  Module,
  PathToImportedNames,
} from "skir-internal";
import { TextEdit } from "./formatter.js";
import { formatImportBlock } from "./import_block_formatter.js";
import { ModuleSet } from "./module_set.js";
export {
  declarationsToExpectedNames,
  ExpectedNamesCollector,
} from "./expected_names.js";

export interface CompletionItem {
  readonly name: string;
  readonly doc?: Doc;
  /** Set if the item requires an automatic import. */
  readonly modulePath?: string;
  /**
   * Set if the text to insert when the user selects the item is different from 'name'.
   * Example: name is "foo", insert text is "module_alias.Foo" or ".Foo".
   */
  readonly insertText?: string;
  /**
   * The text edit to add the import statement.
   * Set if the item required an automatic import.
   */
  readonly importBlockEdit?: TextEdit;
}

export interface CompletionItems {
  readonly placeholderStartPos: number;
  readonly placeholderEndPos: number;
  readonly items: readonly CompletionItem[];
}

export function provideCompletionItems(
  modulePath: string,
  moduleContent: string,
  position: number,
  oldModuleSet: ModuleSet,
): CompletionItems | null {
  const modulePathToContent = new Map<string, string>();
  for (const [modulePath, module] of oldModuleSet.modules) {
    modulePathToContent.set(modulePath, module.result.sourceCode);
  }
  modulePathToContent.set(modulePath, moduleContent);

  const moduleResult = ModuleSet.compileForCompletion(
    modulePath,
    position,
    modulePathToContent,
    oldModuleSet,
  );

  for (const error of moduleResult.errors) {
    const { token } = error;
    let startPosition: number;
    let endPosition: number;
    if (token.text.startsWith('"') || token.text.startsWith("'")) {
      startPosition = token.position + 1;
      endPosition = token.position + token.originalText.length - 1;
    } else {
      startPosition = token.position;
      endPosition =
        token.position + (token.text === "..." ? 0 : token.originalText.length);
    }
    if (
      startPosition <= position &&
      position <= endPosition &&
      error.expectedNames?.length
    ) {
      return {
        placeholderStartPos: startPosition,
        placeholderEndPos: endPosition,
        items: error.expectedNames.map((it) =>
          expectedNameToCompletionItem(it, moduleResult.result),
        ),
      };
    }
  }

  return null;
}

function expectedNameToCompletionItem(
  expectedName: ExpectedName,
  module: Module,
): CompletionItem {
  const { modulePath } = expectedName;
  if (!modulePath) {
    return expectedName;
  }
  // Requires an automatic import.
  let insertText: string | undefined;
  // Set if the import block needs to be modified.
  let newPathToImportedNames: PathToImportedNames | undefined;
  // Check if the module is already imported.
  const oldImportedNames = module.pathToImportedNames[modulePath];
  if (oldImportedNames) {
    if (oldImportedNames.kind === "all") {
      // The module is already imported with an alias, we can use the alias.
      // No need to modify the import block.
      insertText = `${oldImportedNames.alias}.${expectedName.name}`;
    } else {
      // Some records from the module are already imported.
      newPathToImportedNames = {
        ...module.pathToImportedNames,
        [modulePath]: {
          kind: "some",
          names: new Set([...oldImportedNames.names, expectedName.name]),
        },
      };
    }
  } else {
    // The module is not imported yet.
    newPathToImportedNames = {
      ...module.pathToImportedNames,
      [modulePath]: {
        kind: "some",
        names: new Set([expectedName.name]),
      },
    };
  }
  let importBlockEdit: TextEdit | undefined;
  if (newPathToImportedNames) {
    const newImportBlock = formatImportBlock(newPathToImportedNames);
    const oldImportBlockRange = module.importBlockRange;
    if (oldImportBlockRange) {
      // Replace the old import block with the new one.
      importBlockEdit = {
        oldStart: oldImportBlockRange.start,
        oldEnd: oldImportBlockRange.end,
        newText: newImportBlock,
      };
    } else {
      // No import block exists, insert the new import block at the top.
      importBlockEdit = {
        oldStart: 0,
        oldEnd: 0,
        newText: `${newImportBlock}\n\n`,
      };
    }
  }
  return {
    ...expectedName,
    insertText: insertText,
    importBlockEdit: importBlockEdit,
  };
}
