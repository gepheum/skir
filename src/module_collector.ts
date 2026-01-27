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
  lenient?: "lenient",
): Promise<ModuleSet> {
  const modules = ModuleSet.create(REAL_FILE_SYSTEM, srcDir);
  modules.mergeFrom(dependencies);
  const skirFiles = await glob(Paths.join(srcDir, "**/*.skir"), {
    stat: true,
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
  for (const skirFile of skirFiles) {
    if (!skirFile.isFile) {
      continue;
    }
    const relativePath = //
      Paths.relative(srcDir, skirFile.fullpath()).replace(/\\/g, "/");

    validate(relativePath);
    modules.parseAndResolve(relativePath);
  }
  return modules;
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
