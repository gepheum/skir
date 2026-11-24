import type { Record } from "skir-internal";
import { ModuleSet } from "./module_set.js";
import { downloadPackage } from "./package_downloader.js";
import type {
  DependenciesResult,
  DependencyError,
  Package,
  PackageDownloader,
  PackageIdToVersion,
  Packages,
} from "./package_types.js";

export class GetDependenciesFlow {
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

interface DependencyItem {
  readonly packageId: string;
  readonly version: string;
}

interface PackageBundle {
  pkg: Package;
  dependencyChain: DependencyItem[];
}

/**
 * Resolves a GitHub blob URL to the first record declared at the referenced line.
 *
 * Expected URL shape:
 *   https://github.com/<owner>/<repo>/blob/<version>/skir-src/<path>.skir#L<line>
 *
 * Returns:
 * - `{ kind: "success", record, moduleSet }` when a record is found.
 * - `{ kind: "error", message }` for invalid URLs, dependency download issues,
 *   compilation failures, missing modules, or when no record starts at the line.
 */
export async function getModuleFromGithubUrl(
  githubUrl: string,
  githubToken: string | undefined,
  packageDownloader: PackageDownloader = downloadPackage,
): Promise<
  | {
      kind: "success";
      record: Record;
      moduleSet: ModuleSet;
    }
  | DependencyError
> {
  const parsedUrl = parseGithubModuleUrl(githubUrl);
  if (parsedUrl.kind === "error") {
    return parsedUrl;
  }

  const { packageId, version, modulePath, lineNumber } = parsedUrl;

  const flow = new GetDependenciesFlow({}, githubToken, packageDownloader);
  const dependenciesResult = await flow.run({
    [packageId]: version,
  });
  if (dependenciesResult.kind === "error") {
    return dependenciesResult;
  }

  const modulePathToContent = new Map<string, string>();
  for (const pkg of Object.values(dependenciesResult.packages)) {
    for (const [path, content] of Object.entries(pkg.modules)) {
      modulePathToContent.set(path, content);
    }
  }

  const moduleSet = ModuleSet.compile(
    modulePathToContent,
    "no-cache",
    "strict",
  );
  if (moduleSet.errors.length > 0) {
    return {
      kind: "error",
      message: moduleSet.errors[0]!.message || "Compilation failed",
    };
  }

  const moduleResult = moduleSet.modules.get(modulePath);
  if (!moduleResult) {
    return {
      kind: "error",
      message: `Module not found: ${modulePath}`,
    };
  }

  const recordAtLine = moduleResult.result.records.find(
    (record) => record.record.name.line.lineNumber === lineNumber,
  );
  if (!recordAtLine) {
    return {
      kind: "error",
      message: `No record found at line ${lineNumber + 1} in ${modulePath}`,
    };
  }

  return {
    kind: "success",
    record: recordAtLine.record,
    moduleSet,
  };
}

export function parseGithubModuleUrl(githubUrl: string):
  | {
      kind: "success";
      packageId: string;
      version: string;
      modulePath: string;
      lineNumber: number;
    }
  | DependencyError {
  const match = githubUrl.match(
    /^https:\/\/github\.com\/([^/]+)\/([^/]+)\/blob\/([^/]+)\/(.+)#L(\d+)$/,
  );
  if (!match) {
    return {
      kind: "error",
      message: `Invalid GitHub URL: ${githubUrl}`,
    };
  }

  const owner = match[1]!;
  const repo = match[2]!;
  const version = match[3]!;
  const repoPath = match[4]!;
  const lineNumberOneBased = Number(match[5]!);

  if (!repoPath.startsWith("skir-src/") || !repoPath.endsWith(".skir")) {
    return {
      kind: "error",
      message: `URL must target a .skir file in skir-src: ${githubUrl}`,
    };
  }
  if (!Number.isInteger(lineNumberOneBased) || lineNumberOneBased <= 0) {
    return {
      kind: "error",
      message: `Invalid line number in URL: ${githubUrl}`,
    };
  }

  const packageId = `@${owner}/${repo}`;
  const modulePath = packageId + repoPath.substring("skir-src".length);

  return {
    kind: "success",
    packageId,
    version,
    modulePath,
    lineNumber: lineNumberOneBased - 1,
  };
}
