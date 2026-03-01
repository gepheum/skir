import { Doc } from "skir-internal";
import { ModuleSet } from "./module_set.js";

export interface CompletionItems {
  readonly placeholderStartPos: number;
  readonly placeholderEndPos: number;
  readonly items: ReadonlyArray<{
    readonly name: string;
    readonly doc?: Doc;
  }>;
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
        items: error.expectedNames,
      };
    }
  }

  return null;
}
