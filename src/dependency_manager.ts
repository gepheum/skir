import * as fs from "fs/promises";
import path from "node:path";
import { AsyncFileReader, REAL_FILE_SYSTEM } from "./io.js";
import { downloadPackage } from "./package_downloader.js";
import type {
  DependenciesResult,
  DependencyError,
  Package,
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

class GetDependenciesFlow {
  private readonly packageBundles: { [packageId: string]: PackageBundle } = {};
  private readonly dependencyChain: DependencyItem[] = [];
  private readonly errors: DependencyError[] = [];
  private allDependenciesOnDisk = true;

  constructor(
    private readonly cachedPackages: Packages,
    private readonly githubToken: string | undefined,
    private readonly packageDownloader: PackageDownloader,
  ) {}

  async run(dependencies: PackageIdToVersion): Promise<DependenciesResult> {
    for (const [packageId, version] of Object.entries(dependencies)) {
      await this.getDependency(packageId, version);
      if (this.errors.length > 0) {
        return this.errors[0]!;
      }
    }

    const changed = !(
      this.allDependenciesOnDisk &&
      Object.keys(dependencies).length ===
        Object.keys(this.cachedPackages).length
    );

    return {
      kind: "success",
      packages: Object.fromEntries(
        Object.entries(this.packageBundles).map(([packageId, bundle]) => [
          packageId,
          bundle.pkg,
        ]),
      ),
      changed: changed,
    };
  }

  private async getDependency(
    packageId: string,
    version: string,
  ): Promise<void> {
    this.dependencyChain.push({ packageId, version });
    try {
      const presentPackage = this.packageBundles[packageId];
      if (presentPackage?.pkg.version === version) {
        return;
      } else if (presentPackage) {
        this.errors.push({
          kind: "error",
          message: [
            `Version conflict for package ${packageId}:`,
            `- ${formatDependencyChain(this.dependencyChain)}`,
            `- ${formatDependencyChain(presentPackage.dependencyChain)}`,
          ].join("\n"),
        });
        return;
      }
      let pkg = this.getCachedPackage(packageId, version);
      if (!pkg) {
        this.allDependenciesOnDisk = false;
        const downloadResult = await this.packageDownloader(
          packageId,
          version,
          this.githubToken,
        );
        if (downloadResult.kind === "success") {
          pkg = downloadResult.package;
        } else {
          this.errors.push(downloadResult);
          return;
        }
      }
      this.packageBundles[packageId] = {
        pkg: pkg,
        dependencyChain: [...this.dependencyChain],
      };
      for (const [depId, depVersion] of Object.entries(pkg.dependencies)) {
        await this.getDependency(depId, depVersion);
      }
    } finally {
      this.dependencyChain.pop();
    }
  }

  private getCachedPackage(
    packageId: string,
    version: string,
  ): Package | undefined {
    const pkg = this.cachedPackages[packageId];
    return pkg?.version === version ? pkg : undefined;
  }
}

function formatDependencyChain(chain: DependencyItem[]): string {
  return (
    "main depends on " +
    chain
      .map((item) => `${item.packageId}:${item.version}`)
      .join(" which depends on ")
  );
}

const DEPENDENCIES_FILENAME = "dependencies.json";

interface DependencyItem {
  readonly packageId: string;
  readonly version: string;
}

interface PackageBundle {
  pkg: Package;
  dependencyChain: DependencyItem[];
}
