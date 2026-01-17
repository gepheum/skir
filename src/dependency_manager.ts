import path from "node:path";
import {
  DependencyDownloader,
  PackageIdToVersion,
  Packages,
} from "./dependency_downloader.js";
import { AsyncFileReader, AsyncFileWriter } from "./io.js";

export class DependencyManager {
  constructor(
    private readonly rootDir: string,
    private readonly dependencyDownloader: DependencyDownloader,
    private readonly fileReader: AsyncFileReader,
    private readonly fileWriter: AsyncFileWriter,
  ) {}

  async getDependencies(dependencies: PackageIdToVersion): Promise<Packages> {
    // TODO: check version constraints, not just exact versions. !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    // Let's check if the dependencies on disk match the requested ones
    const dependenciesOnDisk = await this.readDependenciesFile();
    if (
      Object.entries(dependencies).every(
        ([packageId, version]) =>
          dependenciesOnDisk.packages[packageId]?.version === version,
      )
    ) {
      // All requested dependencies are already on disk.
      // But there is another condition we need to check: are all dependencies
      // on disk still needed?
      const requiredPackageIds = collectPackageIdsRecursively(
        dependencies,
        dependenciesOnDisk,
      );
      if (
        Object.keys(dependenciesOnDisk).every((packageId) =>
          requiredPackageIds.has(packageId),
        )
      ) {
        // We can just return the dependencies on disk as-is.
        return dependenciesOnDisk;
      } else {
        // Filter out unneeded dependencies.
        const packages = {
          packages: Object.fromEntries(
            Object.entries(dependenciesOnDisk.packages).filter(
              ([packageId, _]) => requiredPackageIds.has(packageId),
            ),
          ),
        };
        await this.writeOnDisk(packages);
        return packages;
      }
    } else {
      // Download the requested dependencies.
      const response = await this.dependencyDownloader.downloadDependencies({
        dependencies: dependencies,
      });
      if (response.kind === "success") {
        const { packages } = response;
        await this.writeOnDisk(packages);
        return packages;
      } else if (response.kind === "error") {
        // TODO: better error message
        throw new Error(`Failed to download dependencies: ${response.message}`);
      } else {
        const _: never = response;
        throw new Error();
      }
    }
  }

  private readonly externalDir = path.join(this.rootDir, "skir-external");

  async readDependenciesFile(): Promise<Packages> {
    const { dependenciesPath } = this;
    const content = await this.fileReader.readTextFileAsync(dependenciesPath);
    if (content === undefined) {
      return { packages: {} };
    }
    try {
      return JSON.parse(content) as Packages;
    } catch (error) {
      console.error(`Failed to parse ${dependenciesPath}:`, error);
      return { packages: {} };
    }
  }

  async writeOnDisk(packages: Packages): Promise<void> {
    const { dependenciesPath } = this;
    const json = JSON.stringify(packages, null, 2);
    try {
      await this.fileWriter.writeTextFileAsync(dependenciesPath, json);
    } catch (error) {
      console.error(`Failed to write ${dependenciesPath}:`, error);
    }

    // TODO: write the modules...
  }

  private get dependenciesPath(): string {
    return path.join(this.rootDir, "skir-external", "dependencies.json");
  }
}

function collectPackageIdsRecursively(
  dependencies: PackageIdToVersion,
  packages: Packages,
): Set<string> {
  const result = new Set<string>();
  const collect = (packageId: string): void => {
    if (result.has(packageId)) {
      return;
    }
    result.add(packageId);
    const package_ = packages.packages[packageId]!;
    for (const packageId of Object.keys(package_.dependencies)) {
      collect(packageId);
    }
  };
  for (const packageId of Object.keys(dependencies)) {
    collect(packageId);
  }
  return result;
}
