import * as fs from "fs/promises";
import path from "node:path";
import { GetDependenciesFlow } from "./get_dependencies_flow.js";
import { AsyncFileReader, REAL_FILE_SYSTEM } from "./io.js";
import { downloadPackage } from "./package_downloader.js";
import type {
  DependenciesResult,
  PackageDownloader,
  PackageIdToVersion,
  Packages,
} from "./package_types.js";

export class DependencyManager {
  constructor(
    private readonly rootDir: string,
    private readonly githubToken: string | undefined,
    private readonly fileReader: AsyncFileReader = REAL_FILE_SYSTEM,
    private readonly packageDownloader: PackageDownloader = downloadPackage,
  ) {}

  async getDependencies(
    dependencies: PackageIdToVersion,
    writeOption: "write" | "no-write" = "write",
  ): Promise<DependenciesResult> {
    const flow = new GetDependenciesFlow(
      await this.readDependenciesFile(),
      this.githubToken,
      this.packageDownloader,
    );
    const result = await flow.run(dependencies);
    if (
      result.kind === "success" &&
      writeOption === "write" &&
      result.changed
    ) {
      await this.writeOnDisk(result.packages);
    }
    return result;
  }

  private async writeOnDisk(packages: Packages): Promise<void> {
    // Write everything to a temp directory first, then rename it.

    const relPathToContent = new Map<string, string>();
    for (const [packageId, pkg] of Object.entries(packages)) {
      for (const [modulePath, content] of Object.entries(pkg.modules)) {
        const relPath =
          packageId +
          modulePath
            .substring(packageId.length)
            .replace(/\.skir$/, ".readonly.skir");
        relPathToContent.set(relPath, content);
      }
    }
    relPathToContent.set(
      DEPENDENCIES_FILENAME,
      JSON.stringify(packages, null, 2),
    );

    const unixMillis = Date.now();
    const tempDir = this.externalDir + "." + unixMillis + ".tmp";
    const limboDir = this.externalDir + ".~" + unixMillis + ".tmp";

    let tempDirExists = false;
    let limboDirExists = false;
    try {
      await fs.mkdir(tempDir, { recursive: true });
      tempDirExists = true;

      // Write all files in parallel
      const writePromises = Array.from(relPathToContent.entries()).map(
        async ([relPath, content]) => {
          const fullPath = path.join(tempDir, relPath);
          const dir = path.dirname(fullPath);
          await fs.mkdir(dir, { recursive: true });
          await fs.writeFile(fullPath, content, "utf-8");
        },
      );
      await Promise.all(writePromises);

      try {
        await fs.rename(this.externalDir, limboDir);
      } catch (error) {
        // It's okay if externalDir doesn't exist yet.
        const doesNotExist =
          error &&
          typeof error === "object" &&
          "code" in error &&
          error.code === "ENOENT";
        if (!doesNotExist) {
          throw error;
        }
      }
      limboDirExists = true;
      await fs.rename(tempDir, this.externalDir);
      tempDirExists = false;
      await fs.rm(limboDir, { recursive: true, force: true });
      limboDirExists = false;
    } finally {
      if (tempDirExists) {
        try {
          await fs.rm(tempDir, { recursive: true, force: true });
        } catch (e) {
          console.error(e);
        }
      }
      if (limboDirExists) {
        try {
          await fs.rm(limboDir, { recursive: true, force: true });
        } catch (e) {
          console.error(e);
        }
      }
    }
  }

  private get externalDir(): string {
    return path.join(this.rootDir, "skir-external");
  }

  private async readDependenciesFile(): Promise<Packages> {
    const dependenciesPath = path.join(this.externalDir, DEPENDENCIES_FILENAME);
    const content = await this.fileReader.readTextFileAsync(dependenciesPath);
    if (content === undefined) {
      return {};
    }
    try {
      return JSON.parse(content) as Packages;
    } catch (error) {
      console.error(`Failed to parse ${dependenciesPath}:`, error);
      return {};
    }
  }
}

const DEPENDENCIES_FILENAME = "dependencies.json";
