import * as ccGen from "skir-cc-gen";
import * as dartGen from "skir-dart-gen";
import { CodeGenerator } from "skir-internal";
import * as javaGen from "skir-java-gen";
import * as kotlinGen from "skir-kotlin-gen";
import * as pythonGen from "skir-python-gen";
import * as typescriptGen from "skir-typescript-gen";
import { LineCounter, parseDocument, Scalar, YAMLMap } from "yaml";
import { SkirConfig } from "./config.js";

export interface SkirConfigResult {
  skirConfig: SkirConfig | undefined;
  errors: readonly SkirConfigError[];
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

export async function parseSkirConfig(
  yamlCode: string,
  importMods?: "import-mods",
): Promise<SkirConfigResult> {
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

  // Check for YAML parsing errors
  if (doc.errors.length > 0) {
    for (const error of doc.errors) {
      const range = offsetRangeToRange(error.pos[0], error.pos[1]);
      errors.push({
        message: error.message,
        range: range,
      });
    }
    return { skirConfig: undefined, errors: errors };
  }

  const jsData = doc.toJS();

  // 2. Validate with Zod schema
  const result = SkirConfig.safeParse(jsData);

  if (!result.success) {
    for (const issue of result.error.issues) {
      // Map the Zod path to the YAML node
      const range = pathToRange(issue.path);
      errors.push({
        message: issue.message,
        range: range,
      });
    }
    return { skirConfig: undefined, errors: errors };
  }

  // 3. Validate each generator's config with Zod schema
  for (let i = 0; i < result.data.generators.length; i++) {
    const generatorConfig = result.data.generators[i]!;
    const { mod } = generatorConfig;
    let generator: CodeGenerator<unknown> | undefined;
    if (importMods) {
      try {
        generator = await importCodeGenerator(mod);
      } catch (e) {
        if (e instanceof Error) {
          const range = pathToRange(["generators", i, "mod"]);
          errors.push({
            message: e.message,
            range: range,
          });
          continue;
        } else {
          throw e;
        }
      }
    } else {
      // TODO: rm the casts
      const modToGenerator: Record<string, CodeGenerator<unknown>> = {
        "skir-cc-gen": ccGen.GENERATOR as any as CodeGenerator<unknown>,
        "skir-dart-gen": dartGen.GENERATOR as any as CodeGenerator<unknown>,
        "skir-java-gen": javaGen.GENERATOR as any as CodeGenerator<unknown>,
        "skir-kotlin-gen": kotlinGen.GENERATOR as any as CodeGenerator<unknown>,
        "skir-python-gen": pythonGen.GENERATOR as any as CodeGenerator<unknown>,
        "skir-typescript-gen":
          typescriptGen.GENERATOR as any as CodeGenerator<unknown>,
      };
      generator = modToGenerator[mod];
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
          const range = pathToRange(path);
          errors.push({
            message: issue.message ?? "Error",
            range: range,
          });
        }
      }
    }
  }
  if (errors.length > 0) {
    return { skirConfig: undefined, errors: errors };
  }

  return { skirConfig: result.data, errors: [] };
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
