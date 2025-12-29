import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { checkBackwardCompatibility } from "./compatibility_checker.js";
import {
  formatError,
  makeGreen,
  makeRed,
  renderBreakingChanges,
  renderErrors,
} from "./error_renderer.js";
import { rewritePathForRendering } from "./io.js";
import { collectModules } from "./module_collector.js";
import { ModuleSet } from "./module_set.js";

export async function takeSnapshot(args: {
  rootDir: string;
  srcDir: string;
  subcommand: "ci" | "dry-run" | undefined;
}): Promise<boolean> {
  const newModuleSet = await collectModules(args.srcDir);
  if (newModuleSet.errors.length) {
    renderErrors(newModuleSet.errors);
    return false;
  }
  const snapshotPath = join(args.rootDir, "skir-snapshot.json");
  const oldModuleSet = await readLastSnapshot(snapshotPath);
  if (!(oldModuleSet instanceof ModuleSet)) {
    console.error(
      makeRed(
        `Corrupted snapshot file: ${rewritePathForRendering(snapshotPath)}`,
      ),
    );
    console.error(`Error: ${oldModuleSet.error.toString()}`);
    console.log(
      "If the snapshot file cannot be restored to a valid state, delete it and run again. " +
        "Breaking changes from recent commits will not be detected, but a valid snapshot will be created for future comparisons.",
    );
    return false;
  }
  const breakingChanges = checkBackwardCompatibility({
    before: oldModuleSet,
    after: newModuleSet,
  });
  if (breakingChanges.length) {
    renderBreakingChanges(breakingChanges, {
      before: oldModuleSet,
      after: newModuleSet,
    });
    return false;
  }
  const now = new Date();
  const newSnapshot = makeSnapshot(newModuleSet, now);
  if (sameModules(newSnapshot, makeSnapshot(oldModuleSet, now))) {
    console.log("No changes detected since last snapshot.");
    return true;
  }
  if (args.subcommand === "ci") {
    console.error(makeRed("Modules have changed since the last snapshot."));
    console.log("Run 'npx skir snapshot' to take a new snapshot.");
    return false;
  } else if (args.subcommand === "dry-run") {
    console.log(makeGreen("Changes detected since last snapshot."));
    console.log("No breaking changes found.");
    return true;
  }
  await writeFile(snapshotPath, JSON.stringify(newSnapshot, null, 2), "utf-8");
  console.log("Snapshot taken. No breaking changes detected.");
  return true;
}

interface CorruptedError {
  kind: "corrupted";
  error: any;
}

async function readLastSnapshot(
  snapshotPath: string,
): Promise<ModuleSet | CorruptedError> {
  let textContent: string;
  try {
    textContent = await readFile(snapshotPath, "utf-8");
  } catch (error) {
    const isNotFoundError =
      error instanceof Error && "code" in error && error.code === "ENOENT";
    if (isNotFoundError) {
      return ModuleSet.fromMap(new Map<string, string>());
    } else {
      // Rethrow I/O error
      throw error;
    }
  }
  return snapshotFileContentToModuleSet(textContent);
}

export function snapshotFileContentToModuleSet(
  fileContent: string,
): ModuleSet | CorruptedError {
  let snapshot: Snapshot;
  try {
    snapshot = JSON.parse(fileContent);
  } catch (error) {
    if (error instanceof SyntaxError) {
      return {
        kind: "corrupted",
        error: error,
      };
    } else {
      throw error;
    }
  }
  const pathToSourceCode = new Map<string, string>();
  try {
    for (const [path, sourceCode] of Object.entries(snapshot.modules)) {
      // + "" to ensure string type
      pathToSourceCode.set(path + "", sourceCode + "");
    }
  } catch (error) {
    return {
      kind: "corrupted",
      error: error,
    };
  }
  const moduleSet = ModuleSet.fromMap(pathToSourceCode);
  if (moduleSet.errors.length) {
    const firstError = formatError(moduleSet.errors[0]!);
    return {
      kind: "corrupted",
      error: new Error(`errors in modules; first error: ${firstError}`),
    };
  }
  return moduleSet;
}

export async function viewSnapshot(args: { rootDir: string }): Promise<void> {
  const snapshotPath = join(args.rootDir, "skir-snapshot.json");
  let snapshot: Snapshot;
  try {
    const textContent = await readFile(snapshotPath, "utf-8");
    snapshot = JSON.parse(textContent);
  } catch (error) {
    if (error instanceof SyntaxError) {
      console.error(makeRed(`Corrupted snapshot file: ${snapshotPath}`));
      console.error(`Error: ${error.toString()}`);
      process.exit(1);
    }
    const isNotFoundError =
      error instanceof Error && "code" in error && error.code === "ENOENT";
    if (isNotFoundError) {
      console.log("No snapshot found.");
      return;
    } else {
      // Rethrow I/O error
      throw error;
    }
  }

  console.log(`Last snapshot: ${snapshot.lastChange}\n`);

  const modulePaths = Object.keys(snapshot.modules).sort();
  for (const path of modulePaths) {
    console.log(makeGreen("-".repeat(80)));
    console.log(makeGreen(path));
    console.log(makeGreen("-".repeat(80)));
    console.log();
    const sourceCode = snapshot.modules[path]!;
    console.log(sourceCode);
    console.log();
  }
}

function makeSnapshot(moduleSet: ModuleSet, now: Date): Snapshot {
  const modules: { [path: string]: string } = {};
  for (const module of moduleSet.resolvedModules) {
    modules[module.path] = module.sourceCode;
  }
  return {
    readMe: "DO NOT EDIT. To update, run: npx skir snapshot",
    lastChange: now.toISOString(),
    modules,
  };
}

function sameModules(a: Snapshot, b: Snapshot): boolean {
  return (
    Object.keys(a.modules).length === Object.keys(b.modules).length &&
    Object.entries(a.modules).every(([path, sourceCode]) => {
      return sourceCode === b.modules[path];
    })
  );
}

interface Snapshot {
  readMe: string;
  lastChange: string;
  modules: { [path: string]: string };
}
