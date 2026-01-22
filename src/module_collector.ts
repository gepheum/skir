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
    const relativePath = Paths.relative(srcDir, skirFile.fullpath()).replace(
      /\\/g,
      "/",
    );
    modules.parseAndResolve(relativePath);
  }
  return modules;
}
