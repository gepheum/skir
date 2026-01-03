import * as CcGen from "skir-cc-gen";
import * as DartGen from "skir-dart-gen";
import { CodeGenerator } from "skir-internal";
import * as JavaGen from "skir-java-gen";
import * as KotlinGen from "skir-kotlin-gen";
import * as PythonGen from "skir-python-gen";
import * as TypescriptGen from "skir-typescript-gen";
import { LineCounter, parseDocument, Scalar, YAMLMap } from "yaml";
import { SkirConfig } from "./config.js";

export interface SkirConfigResult {
  /** Defined if and only if `errors` is empty. */
  skirConfig: SkirConfig | undefined;
  errors: readonly SkirConfigError[];
  /**
   * If true, the user may have forgotten to edit skir.yml after running
   * `npx skir init`.
   */
  maybeForgotToEditAfterInit?: boolean;
}

export interface SkirConfigError {
  message: string;
  range?: SkirConfigErrorRange;
}

export interface SkirConfigErrorRange {
  start: SkirConfigErrorPos;
  end: SkirConfigErrorPos;
}

export interface SkirConfigErrorPos {
  /** 0-based */
  offset: number;
  /** 1-based */
  lineNumber: number;
  /** 2-based */
  colNumber: number;
}

/** Synchronous version - doesn't import any module. */
export function parseSkirConfig(yamlCode: string): SkirConfigResult {
  return parseSkirConfigInternal(yamlCode, (mod) => STATIC_GENERATORS[mod]);
}

/** Async version - dynamically imports generator modules. */
export async function parseSkirConfigWithDynamicImports(
  yamlCode: string,
): Promise<SkirConfigResult> {
  return parseSkirConfigInternalAsync(yamlCode, importCodeGenerator);
}

export async function importCodeGenerator(
  mod: string,
): Promise<CodeGenerator<unknown>> {
  const module = await import(mod);
  const generator = module.GENERATOR;
  if (typeof generator !== "object") {
    throw new Error(`Cannot import GENERATOR from module ${mod}`);
  }
  return generator as CodeGenerator<unknown>;
}

interface ParsedYamlResult {
  earlyReturn?: SkirConfigResult;
  zodResult: ReturnType<typeof SkirConfig.safeParse>;
  errors: SkirConfigError[];
  pushErrorAtPath: (path: readonly PropertyKey[], message: string) => void;
}

function parseYaml(yamlCode: string): ParsedYamlResult {
  const errors: SkirConfigError[] = [];

  // 1. Parse YAML into a Document object
  const lineCounter = new LineCounter();
  const doc = parseDocument(yamlCode, { lineCounter });

  const offsetToPos = (offset: number): SkirConfigErrorPos => {
    const pos = lineCounter.linePos(offset);
    return {
      offset: offset,
      lineNumber: pos.line,
      colNumber: pos.col,
    };
  };
  const offsetRangeToRange = (
    start: number,
    end: number,
  ): SkirConfigErrorRange => ({
    start: offsetToPos(start),
    end: offsetToPos(end),
  });
  const pathToRange = (
    path: readonly PropertyKey[],
  ): SkirConfigErrorRange | undefined => {
    const node = doc.getIn(path, true) as Scalar | YAMLMap | undefined;
    if (!node || !node.range) {
      return undefined;
    }
    return offsetRangeToRange(node.range[0], node.range[1]);
  };
  const pushErrorAtPath = (
    path: readonly PropertyKey[],
    message: string,
  ): void => {
    const pathRemainder: PropertyKey[] = [];
    while (path.length !== 0) {
      const range = pathToRange(path);
      if (range) {
        break;
      } else {
        // It's possible that 'path' does not map to a node if 'path' refers to
        // a property which is missing. In that case, we pop the last element
        // of 'path' and try again, until we find a node that exists. The
        // elements which were popped will be included in the error message.
        pathRemainder.push(path.at(-1)!);
        path = path.slice(0, -1);
      }
    }
    pathRemainder.reverse();
    const pathRemainderStr = pathRemainder
      .map((p, i) =>
        typeof p === "number" ? `[${p}]` : i === 0 ? p : `.${String(p)}`,
      )
      .join("");
    const messagePrefix = pathRemainder.length
      ? `Missing property '${pathRemainderStr}': `
      : "";
    const range = pathToRange(path);
    errors.push({
      message: messagePrefix + message,
      range: range,
    });
  };

  // Check for YAML parsing errors
  if (doc.errors.length > 0) {
    for (const error of doc.errors) {
      const range = offsetRangeToRange(error.pos[0], error.pos[1]);
      errors.push({
        message: error.message,
        range: range,
      });
    }
    return {
      earlyReturn: {
        skirConfig: undefined,
        errors: errors,
      },
      zodResult: { success: false } as any,
      errors,
      pushErrorAtPath,
    };
  }

  // 2. Validate with Zod schema
  const jsData = doc.toJS();
  const zodResult = SkirConfig.safeParse(jsData);

  if (!zodResult.success) {
    for (const issue of zodResult.error.issues) {
      pushErrorAtPath(issue.path, issue.message);
    }
    const maybeForgotToEditAfterInit: boolean | undefined =
      jsData &&
      typeof jsData === "object" &&
      "generators" in jsData &&
      jsData.generators === null
        ? true
        : false;
    return {
      earlyReturn: {
        skirConfig: undefined,
        errors: errors,
        maybeForgotToEditAfterInit,
      },
      zodResult,
      errors,
      pushErrorAtPath,
    };
  }

  return {
    zodResult,
    errors,
    pushErrorAtPath,
  };
}

function parseSkirConfigInternal(
  yamlCode: string,
  getGenerator: (mod: string) => CodeGenerator<unknown> | undefined,
): SkirConfigResult {
  const { earlyReturn, errors, zodResult, pushErrorAtPath } =
    parseYaml(yamlCode);

  if (earlyReturn) {
    return earlyReturn;
  }

  // Validate each generator's config with Zod schema
  for (let i = 0; i < zodResult.data!.generators.length; i++) {
    const generatorConfig = zodResult.data!.generators[i]!;
    const { mod } = generatorConfig;
    const generator = getGenerator(mod);
    if (generator) {
      const parsedGeneratorConfig = generator.configType.safeParse(
        generatorConfig.config,
      );
      if (!parsedGeneratorConfig.success) {
        for (const issue of parsedGeneratorConfig.error.issues) {
          const path: readonly PropertyKey[] = [
            "generators",
            i,
            "config",
            ...issue.path,
          ];
          pushErrorAtPath(path, issue.message ?? "Error");
        }
      }
    }
  }
  if (errors.length > 0) {
    return { skirConfig: undefined, errors: errors };
  }

  return { skirConfig: zodResult.data!, errors: [] };
}

async function parseSkirConfigInternalAsync(
  yamlCode: string,
  getGenerator: (mod: string) => Promise<CodeGenerator<unknown>>,
): Promise<SkirConfigResult> {
  const { earlyReturn, errors, zodResult, pushErrorAtPath } =
    parseYaml(yamlCode);

  if (earlyReturn) {
    return earlyReturn;
  }

  // Validate each generator's config with Zod schema
  for (let i = 0; i < zodResult.data!.generators.length; i++) {
    const generatorConfig = zodResult.data!.generators[i]!;
    const { mod } = generatorConfig;
    let generator: CodeGenerator<unknown> | undefined;
    try {
      generator = await getGenerator(mod);
    } catch (e) {
      if (e instanceof Error) {
        pushErrorAtPath(["generators", i, "mod"], e.message);
        continue;
      } else {
        throw e;
      }
    }
    if (generator) {
      const parsedGeneratorConfig = generator.configType.safeParse(
        generatorConfig.config,
      );
      if (!parsedGeneratorConfig.success) {
        for (const issue of parsedGeneratorConfig.error.issues) {
          const path: readonly PropertyKey[] = [
            "generators",
            i,
            "config",
            ...issue.path,
          ];
          pushErrorAtPath(path, issue.message ?? "Error");
        }
      }
    }
  }
  if (errors.length > 0) {
    return { skirConfig: undefined, errors: errors };
  }

  return { skirConfig: zodResult.data!, errors: [] };
}

// TODO: remove the casts
const STATIC_GENERATORS: Record<string, CodeGenerator<unknown>> = {
  "skir-cc-gen": CcGen.GENERATOR as any as CodeGenerator<unknown>,
  "skir-dart-gen": DartGen.GENERATOR as any as CodeGenerator<unknown>,
  "skir-java-gen": JavaGen.GENERATOR as any as CodeGenerator<unknown>,
  "skir-kotlin-gen": KotlinGen.GENERATOR as any as CodeGenerator<unknown>,
  "skir-python-gen": PythonGen.GENERATOR as any as CodeGenerator<unknown>,
  "skir-typescript-gen":
    TypescriptGen.GENERATOR as any as CodeGenerator<unknown>,
};
