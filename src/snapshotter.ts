import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { RecordLocation, ResolvedType } from "skir-internal";
import { checkCompatibility } from "./compatibility_checker.js";
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
  dependencies: ModuleSet;
  subcommand: "ci" | "dry-run" | undefined;
}): Promise<boolean> {
  const newModuleSet = await collectModules(args.srcDir, args.dependencies);
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
  const breakingChanges = checkCompatibility({
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

  const trackedRecordCount = newSnapshot.trackedRecordIds.length;
  const untrackedRecordCount = newSnapshot.untrackedRecordIds.length;
  const formatCount = (n: number, what: string): string => {
    return `${n} ${what}${n === 1 ? "" : "s"}`;
  };
  console.log(
    [
      formatCount(trackedRecordCount, "tracked record"),
      ", ",
      formatCount(untrackedRecordCount, "untracked record"),
      " found in new snapshot.",
    ].join(""),
  );
  console.log("See them in " + rewritePathForRendering(snapshotPath));

  if (trackedRecordCount === 0) {
    console.log(makeRed("Warning: no tracked records found."));
    console.log(
      "Breaking changes cannot be detected without tracking records.",
    );
    console.log(
      "To track a record and its dependencies, give it a stable identifier, e.g.:",
    );
    console.log("  struct MyStruct(56789) { ... }");
  }

  return true;
}

export interface CorruptedError {
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
      return ModuleSet.compile(new Map<string, string>());
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
  const moduleSet = ModuleSet.compile(pathToSourceCode);
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
  for (const [path, moduleResult] of moduleSet.modules) {
    if (moduleResult.errors.length === 0) {
      modules[path] = moduleResult.result.sourceCode;
    }
  }
  const trackedRecordIds = collectTrackedRecords(moduleSet);
  return {
    readMe: [
      "DO NOT EDIT THIS FILE MANUALLY",
      "",
      "Goal: find breaking changes since the last snapshot",
      "",
      "To update this file (take a new snapshot), run:",
      "  npx skir snapshot",
      "",
      "If you just want to check that there are no breaking changes:",
      "  npx skir snapshot --dry",
      "",
      "Commit this file to version control (do not add to .gitignore)",
      "It is good practice to always take a snapshot before committing",
      "To verify the snapshot is up-to-date in CI:",
      "  npx skir snapshot --ci",
    ],
    lastChange: now.toISOString(),
    trackedRecordIds: Array.from(trackedRecordIds.trackedRecordIds).sort(),
    untrackedRecordIds: Array.from(trackedRecordIds.untrackedRecordIds).sort(),
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
  readMe: readonly string[];
  lastChange: string;
  trackedRecordIds: readonly string[];
  untrackedRecordIds: readonly string[];
  modules: Readonly<{ [path: string]: string }>;
}

interface TrackedRecords {
  trackedRecordIds: ReadonlySet<string>;
  untrackedRecordIds: ReadonlySet<string>;
}

function collectTrackedRecords(moduleSet: ModuleSet): TrackedRecords {
  const seenRecordIds = new Set<string>();
  const trackedRecordIds = new Set<string>();

  const getRecordId = (record: RecordLocation): string => {
    const qualifiedName = record.recordAncestors
      .map((token) => token.name.text)
      .join(".");
    return `${record.modulePath}:${qualifiedName}`;
  };

  const getRecordForType = (type: ResolvedType): RecordLocation | null => {
    switch (type.kind) {
      case "array":
        return getRecordForType(type.item);
      case "optional":
        return getRecordForType(type.other);
      case "primitive":
        return null;
      case "record":
        return moduleSet.recordMap.get(type.key) ?? null;
    }
  };

  const processRecord = (record: RecordLocation): void => {
    const recordId = getRecordId(record);
    if (seenRecordIds.has(recordId)) {
      return;
    }
    seenRecordIds.add(recordId);
    if (record.record.recordNumber === null) {
      return;
    }
    trackedRecordIds.add(recordId);
    // Recursively process the field/variant types
    for (const field of record.record.fields) {
      const fieldType = field.type;
      if (fieldType) {
        const fieldRecord = getRecordForType(fieldType);
        if (fieldRecord) {
          processRecord(fieldRecord);
        }
      }
    }
  };

  for (const record of moduleSet.recordMap.values()) {
    processRecord(record);
  }
  const untrackedRecordIds = new Set(
    [...seenRecordIds].filter((id) => !trackedRecordIds.has(id)),
  );
  return {
    trackedRecordIds: trackedRecordIds,
    untrackedRecordIds: untrackedRecordIds,
  };
}
