import { glob } from "glob";
import * as Paths from "path";
import { ExitError } from "./exit_error.js";
import {
  isDirectory,
  REAL_FILE_SYSTEM,
  rewritePathForRendering,
} from "./io.js";
import { ModuleSet } from "./module_set.js";

export async function collectModules(
  srcDir: string,
  dependencies: ModuleSet,
  cache?: ModuleSet,
): Promise<ModuleSet> {
  const modulePathToContent = new Map<string, string>();
  for (const [modulePath, module] of dependencies.modules) {
    modulePathToContent.set(modulePath, module.result.sourceCode);
  }
  const editableModules = await collectEditableModules(srcDir);
  for (const { modulePath, content } of editableModules) {
    modulePathToContent.set(modulePath, content);
  }
  return ModuleSet.compile(modulePathToContent, cache ?? dependencies);
}

export interface EditableModule {
  readonly fullPath: string;
  readonly modulePath: string;
  readonly content: string;
}

export async function collectEditableModules(
  srcDir: string,
): Promise<ReadonlyArray<EditableModule>> {
  const skirFiles = await glob(Paths.join(srcDir, "**/*.skir"), {
    withFileTypes: true,
  });
  if (skirFiles.length === 0) {
    const isDir = await isDirectory(srcDir);
    if (!isDir) {
      throw new ExitError(
        "Source directory does not exist: " + rewritePathForRendering(srcDir),
      );
    }
  }

  const modules = skirFiles
    .filter((skirFile) => skirFile.isFile)
    .map(async (skirFile): Promise<EditableModule> => {
      const fullPath = skirFile.fullpath();
      const relativePath = Paths.relative(srcDir, fullPath).replace(/\\/g, "/");

      validate(relativePath);
      const content = await REAL_FILE_SYSTEM.readTextFileAsync(fullPath);
      if (content === undefined) {
        throw new ExitError("Cannot read " + rewritePathForRendering(fullPath));
      }
      return {
        fullPath: fullPath,
        modulePath: relativePath,
        content: content,
      };
    });

  return Promise.all(modules);
}

function validate(relativePath: string): void {
  const parts = relativePath.split("/");

  for (let i = 0; i < parts.length; i++) {
    const part = parts[i]!;
    const path = parts.slice(0, i + 1).join("/");
    if (i < parts.length - 1) {
      if (i === 0 && part === "external") {
        throw makeInvalidPathError(path, "directory", "cannot be 'external'");
      } else {
        const regex = /^[a-z_][a-z0-9_-]+$/;
        if (!regex.test(part)) {
          throw makeInvalidPathError(
            path,
            "directory",
            `must match ${regex.source}`,
          );
        }
      }
    } else {
      const regex = /^[a-z_][a-z0-9_-]+\.skir$/;
      if (!regex.test(part)) {
        throw makeInvalidPathError(path, "file", `must match ${regex.source}`);
      }
    }
  }
}

function makeInvalidPathError(
  path: string,
  kind: "file" | "directory",
  info: string,
): ExitError {
  const message = `Invalid ${kind} name: skir-src/${path}; ${info}`;
  return new ExitError(message);
}
