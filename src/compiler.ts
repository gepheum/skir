#!/usr/bin/env node
import * as FileSystem from "fs/promises";
import { glob } from "glob";
import * as Paths from "path";
import type { CodeGenerator } from "skir-internal";
import Watcher from "watcher";
import { parseCommandLine } from "./command_line_parser.js";
import { GeneratorConfig } from "./config.js";
import { importCodeGenerator, parseSkirConfig } from "./config_parser.js";
import {
  makeGray,
  makeGreen,
  makeRed,
  renderErrors,
  renderSkirConfigErrors,
} from "./error_renderer.js";
import { ExitError } from "./exit_error.js";
import { formatModule } from "./formatter.js";
import {
  isDirectory,
  REAL_FILE_SYSTEM,
  rewritePathForRendering,
} from "./io.js";
import { collectModules } from "./module_collector.js";
import { ModuleSet } from "./module_set.js";
import { initializeProject } from "./project_initializer.js";
import { takeSnapshot, viewSnapshot } from "./snapshotter.js";
import { tokenizeModule } from "./tokenizer.js";

interface GeneratorBundle<Config = unknown> {
  generator: CodeGenerator<Config>;
  config: Config;
  /// Absolute paths to the skirout directories.
  skiroutDirs: string[];
}

async function makeGeneratorBundle(
  config: GeneratorConfig,
  root: string,
): Promise<GeneratorBundle> {
  const generator = await importCodeGenerator(config.mod);
  let skiroutDirs: string[];
  if (typeof config.outDir === "string") {
    skiroutDirs = [config.outDir];
  } else {
    skiroutDirs = config.outDir;
  }
  skiroutDirs = skiroutDirs.map((d) => Paths.join(root, d));
  return {
    generator: generator,
    config: config.config,
    skiroutDirs: skiroutDirs,
  };
}

interface WriteBatch {
  /** Key: path to a generated file relative to the skirout dir. */
  readonly pathToFile: ReadonlyMap<string, CodeGenerator.OutputFile>;
  readonly writeTime: Date;
}

class WatchModeMainLoop {
  private readonly skiroutDirs = new Set<string>();

  constructor(
    private readonly srcDir: string,
    private readonly generatorBundles: readonly GeneratorBundle[],
    private readonly watchModeOn: boolean,
  ) {
    for (const generatorBundle of generatorBundles) {
      for (const skiroutDir of generatorBundle.skiroutDirs) {
        this.skiroutDirs.add(skiroutDir);
      }
    }
    checkNoOverlappingSkiroutDirs([...this.skiroutDirs]);
  }

  async start(): Promise<void> {
    await this.generate();
    const watcher = new Watcher(this.srcDir, {
      renameDetection: true,
      recursive: true,
      persistent: true,
    });
    watcher.on("all", (_, targetPath, targetPathNext) => {
      if (
        targetPath.endsWith(".skir") ||
        (targetPathNext && targetPathNext.endsWith(".skir"))
      ) {
        this.triggerGeneration();
      }
    });
  }

  private triggerGeneration(): void {
    if (this.generating) {
      this.mustRegenerate = true;
      return;
    }
    if (this.timeoutId !== undefined) {
      globalThis.clearTimeout(this.timeoutId);
    }
    const delayMillis = 200;
    const callback = (): void => {
      try {
        this.generate();
      } catch (e) {
        const message =
          e && typeof e === "object" && "message" in e ? e.message : e;
        console.error(message);
      }
    };
    this.timeoutId = globalThis.setTimeout(callback, delayMillis);
  }

  async generate(): Promise<boolean> {
    this.generating = true;
    this.timeoutId = undefined;
    this.mustRegenerate = false;
    if (this.watchModeOn) {
      console.clear();
    }
    try {
      const moduleSet = await collectModules(this.srcDir);
      const errors = moduleSet.errors.filter((e) => !e.errorIsInOtherModule);
      if (errors.length) {
        renderErrors(errors);
        return false;
      } else {
        if (moduleSet.recordMap.size <= 0) {
          console.error(makeRed("No skir modules found in source directory"));
        }
        await this.doGenerate(moduleSet);
        if (this.watchModeOn) {
          const date = new Date().toLocaleTimeString("en-US");
          const successMessage = `Generation succeeded at ${date}`;
          console.log(makeGreen(successMessage));
          console.log("\nWaiting for changes in files matching:");
          const glob = Paths.resolve(Paths.join(this.srcDir, "/**/*.skir"));
          console.log(`  ${glob}`);
        }
        return true;
      }
    } finally {
      this.generating = false;
      if (this.mustRegenerate) {
        this.triggerGeneration();
      }
    }
  }

  private async doGenerate(moduleSet: ModuleSet): Promise<void> {
    const { skiroutDirs } = this;
    const preExistingAbsolutePaths = new Set<string>();
    for (const skiroutDir of skiroutDirs) {
      await FileSystem.mkdir(skiroutDir, { recursive: true });

      // Collect all the files in all the skirout dirs.
      (
        await glob(Paths.join(skiroutDir, "**/*"), { withFileTypes: true })
      ).forEach((p) => preExistingAbsolutePaths.add(p.fullpath()));
    }

    const pathToFile = new Map<string, CodeGenerator.OutputFile>();
    const pathToGenerator = new Map<string, GeneratorBundle>();
    for (const generator of this.generatorBundles) {
      const files = generator.generator.generateCode({
        modules: moduleSet.resolvedModules,
        recordMap: moduleSet.recordMap,
        config: generator.config,
      }).files;
      for (const file of files) {
        const { path } = file;
        if (pathToFile.has(path)) {
          throw new ExitError(
            "Multiple generators produce " + rewritePathForRendering(path),
          );
        }
        pathToFile.set(path, file);
        pathToGenerator.set(path, generator);
        for (const skiroutDir of generator.skiroutDirs) {
          // Remove this path and all its parents from the set of paths to remove
          // at the end of the generation.
          for (
            let pathToKeep = path;
            pathToKeep !== ".";
            pathToKeep = Paths.dirname(pathToKeep)
          ) {
            preExistingAbsolutePaths.delete(
              Paths.resolve(Paths.join(skiroutDir, pathToKeep)),
            );
          }
        }
      }
    }

    // Write or override all the generated files.
    const { lastWriteBatch } = this;
    await Promise.all(
      Array.from(pathToFile).map(async ([p, newFile]) => {
        const oldFile = lastWriteBatch.pathToFile.get(p);
        const generator = pathToGenerator.get(p)!;
        for (const skiroutDir of generator.skiroutDirs) {
          const fsPath = Paths.join(skiroutDir, p);
          if (oldFile?.code === newFile.code) {
            const mtime = (await FileSystem.stat(fsPath)).mtime;
            if (
              mtime !== null &&
              mtime.getDate() <= lastWriteBatch.writeTime.getDate()
            ) {
              return;
            }
          }
          await FileSystem.mkdir(Paths.dirname(fsPath), { recursive: true });
          await FileSystem.writeFile(fsPath, newFile.code, "utf-8");
        }
      }),
    );

    // Remove all the pre-existing paths which haven't been overridden.
    await Promise.all(
      Array.from(preExistingAbsolutePaths)
        .sort((a, b) => b.localeCompare(a, "en-US"))
        .map(async (p) => {
          try {
            await FileSystem.rm(p, { force: true, recursive: true });
          } catch (_e) {
            // Ignore error.
          }
        }),
    );

    this.lastWriteBatch = {
      pathToFile: pathToFile,
      writeTime: new Date(),
    };
  }

  private timeoutId?: NodeJS.Timeout;
  private generating = false;
  private mustRegenerate = false;
  private lastWriteBatch: WriteBatch = {
    pathToFile: new Map(),
    writeTime: new Date(0),
  };
}

function checkNoOverlappingSkiroutDirs(skiroutDirs: readonly string[]): void {
  for (let i = 0; i < skiroutDirs.length; ++i) {
    for (let j = i + 1; j < skiroutDirs.length; ++j) {
      const dirA = Paths.normalize(skiroutDirs[i]!);
      const dirB = Paths.normalize(skiroutDirs[j]!);

      if (
        dirA.startsWith(dirB + Paths.sep) ||
        dirB.startsWith(dirA + Paths.sep)
      ) {
        throw new ExitError(
          `Overlapping skirout directories: ${dirA} and ${dirB}`,
        );
      }
    }
  }
}

interface ModuleFormatResult {
  formattedCode: string;
  alreadyFormatted: boolean;
}

async function format(root: string, mode: "fix" | "check"): Promise<void> {
  const skirFiles = await glob(Paths.join(root, "**/*.skir"), {
    withFileTypes: true,
  });
  const pathToFormatResult = new Map<string, ModuleFormatResult>();
  for await (const skirFile of skirFiles) {
    if (!skirFile.isFile) {
      continue;
    }
    const unformattedCode = REAL_FILE_SYSTEM.readTextFile(skirFile.fullpath());
    if (unformattedCode === undefined) {
      throw new ExitError(
        "Cannot read " + rewritePathForRendering(skirFile.fullpath()),
      );
    }
    const tokens = tokenizeModule(unformattedCode, "");
    if (tokens.errors.length) {
      renderErrors(tokens.errors);
      process.exit(1);
    }
    const formattedCode = formatModule(tokens.result).newSourceCode;
    pathToFormatResult.set(skirFile.fullpath(), {
      formattedCode: formattedCode,
      alreadyFormatted: formattedCode === unformattedCode,
    });
  }
  let numFilesNotFormatted = 0;
  for (const [path, result] of pathToFormatResult) {
    const relativePath = Paths.relative(root, path).replace(/\\/g, "/");
    if (mode === "fix") {
      if (result.alreadyFormatted) {
        console.log(`${makeGray(relativePath)} (unchanged)`);
      } else {
        REAL_FILE_SYSTEM.writeTextFile(path, result.formattedCode);
        console.log(makeGray(relativePath));
      }
    } else {
      const _: "check" = mode;
      if (result.alreadyFormatted) {
        console.log(`${makeGray(relativePath)} (OK)`);
      } else {
        console.log(makeRed(relativePath));
        ++numFilesNotFormatted;
      }
    }
  }
  if (numFilesNotFormatted) {
    console.log();
    console.log(
      makeRed(
        `${numFilesNotFormatted} file${
          numFilesNotFormatted > 1 ? "s" : ""
        } not formatted; run with 'format fix' to format ${
          numFilesNotFormatted > 1 ? "them" : "it"
        }`,
      ),
    );
    process.exit(1);
  }
}

async function main(): Promise<void> {
  const args = parseCommandLine(process.argv.slice(2));

  const root = args.root || ".";

  if (!(await isDirectory(root))) {
    console.error(makeRed(`Not a directory: ${root}`));
    process.exit(1);
  }

  switch (args.kind) {
    case "init": {
      initializeProject(root);
      return;
    }
    case "help":
    case "error": {
      return;
    }
  }

  const skirConfigPath = rewritePathForRendering(Paths.join(root, "skir.yml"));
  const skirConfigCode = REAL_FILE_SYSTEM.readTextFile(skirConfigPath);
  if (skirConfigCode === undefined) {
    console.error(makeRed(`Cannot find ${skirConfigPath}`));
    process.exit(1);
  }

  const skirConfigResult = await parseSkirConfig(skirConfigCode, "import-mods");
  if (skirConfigResult.errors.length > 0) {
    console.error(makeRed("Invalid skir config"));
    const { maybeForgotToEditAfterInit } = skirConfigResult;
    renderSkirConfigErrors(skirConfigResult.errors, {
      skirConfigPath,
      maybeForgotToEditAfterInit,
    });
    process.exit(1);
  }
  const skirConfig = skirConfigResult.skirConfig!;

  const srcDir = Paths.join(root, skirConfig.srcDir || ".");

  switch (args.kind) {
    case "format": {
      // Check or fix the formatting to the .skir files in the source directory.
      await format(srcDir, args.subcommand === "check" ? "check" : "fix");
      break;
    }
    case "gen": {
      // Run the skir code generators in watch mode or once.
      const generatorBundles: GeneratorBundle[] = await Promise.all(
        skirConfig.generators.map((config) =>
          makeGeneratorBundle(config, root),
        ),
      );
      // Look for duplicates.
      for (let i = 0; i < generatorBundles.length - 1; ++i) {
        const { id } = generatorBundles[i]!.generator;
        if (id === generatorBundles[i + 1]!.generator.id) {
          console.error(makeRed(`Duplicate generator: ${id}`));
          process.exit(1);
        }
      }
      const watch = args.subcommand === "watch";
      const watchModeMainLoop = new WatchModeMainLoop(
        srcDir,
        generatorBundles,
        watch,
      );
      if (watch) {
        await watchModeMainLoop.start();
      } else {
        const success: boolean = await watchModeMainLoop.generate();
        process.exit(success ? 0 : 1);
      }
      break;
    }
    case "snapshot": {
      if (args.subcommand === "view") {
        viewSnapshot({
          rootDir: root,
        });
      } else {
        takeSnapshot({
          rootDir: root,
          srcDir: srcDir,
          check: args.subcommand === "check",
        });
      }
      break;
    }
    default: {
      const _: never = args;
      throw new TypeError(_);
    }
  }
}

try {
  await main();
} catch (e) {
  if (e instanceof Error) {
    console.error(makeRed(e.message));
    if (e instanceof ExitError) {
      process.exit(1);
    }
  }
  throw e;
}
