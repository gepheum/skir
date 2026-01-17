import yaml from "yaml";

export type PackageIdToVersion = Readonly<{
  [packageId: string]: string;
}>;

export interface DependencyDownloaderRequest {
  dependencies: PackageIdToVersion;
}

export type DependencyDownloaderResponse =
  | {
      kind: "success";
      packages: Packages;
    }
  | {
      kind: "error";
      message: string;
    };

export interface Packages {
  readonly packages: Readonly<{ [packageId: string]: Package }>;
}

export interface Package {
  readonly packageId: string;
  readonly version: string;
  readonly modules: Readonly<{ [modulePath: string]: string }>;
  readonly dependencies: PackageIdToVersion;
}

export interface DependencyDownloader {
  downloadDependencies(
    request: DependencyDownloaderRequest,
  ): Promise<DependencyDownloaderResponse>;
}

interface GitHubTreeItem {
  path: string;
  mode: string;
  type: "blob" | "tree";
  sha: string;
  size?: number;
  url: string;
}

interface GitHubTree {
  sha: string;
  url: string;
  tree: GitHubTreeItem[];
  truncated: boolean;
}

export class GithubDependencyDownloader implements DependencyDownloader {
  constructor(private readonly githubToken?: string) {}

  async downloadDependencies(
    request: DependencyDownloaderRequest,
  ): Promise<DependencyDownloaderResponse> {
    try {
      const packages: { [packageId: string]: Package } = {};
      const toProcess: Array<{ packageId: string; version: string }> =
        Object.entries(request.dependencies).map(([packageId, version]) => ({
          packageId,
          version,
        }));
      const processed = new Set<string>();

      while (toProcess.length > 0) {
        const current = toProcess.shift()!;
        const key = `${current.packageId}@${current.version}`;

        if (processed.has(key)) {
          continue;
        }
        processed.add(key);

        const packageResult = await this.downloadPackage(
          current.packageId,
          current.version,
        );

        if (!packageResult.success) {
          return {
            kind: "error",
            message: packageResult.error,
          };
        }

        packages[current.packageId] = packageResult.package;

        // Add transitive dependencies to the queue
        for (const [depId, depVersion] of Object.entries(
          packageResult.package.dependencies,
        )) {
          if (!processed.has(`${depId}@${depVersion}`)) {
            toProcess.push({ packageId: depId, version: depVersion });
          }
        }
      }

      return {
        kind: "success",
        packages: { packages },
      };
    } catch (error) {
      return {
        kind: "error",
        message: error instanceof Error ? error.message : String(error),
      };
    }
  }

  private async downloadPackage(
    packageId: string,
    version: string,
  ): Promise<
    { success: true; package: Package } | { success: false; error: string }
  > {
    try {
      // Convert package ID like "@foo/bar" to GitHub repo "foo/bar"
      const repo = this.packageIdToRepo(packageId);

      // Get the repository tree for the specific version
      const tree = await this.getGithubTree(repo, version);

      // Find all .skir files in the skir-src directory
      const skirFiles = tree.tree.filter(
        (item) =>
          item.type === "blob" &&
          item.path.startsWith("skir-src/") &&
          item.path.endsWith(".skir"),
      );

      // Download the content of each .skir file
      const modules: { [modulePath: string]: string } = {};
      for (const file of skirFiles) {
        const content = await this.downloadFileContent(repo, file.sha);
        // Get relative path from skir-src/
        const modulePath = file.path.substring("skir-src/".length);
        modules[modulePath] = content;
      }

      // Try to download and parse skir.yml for dependencies
      const skirYmlFile = tree.tree.find(
        (item) => item.type === "blob" && item.path === "skir.yml",
      );

      let dependencies: PackageIdToVersion = {};
      if (skirYmlFile) {
        try {
          const skirYmlContent = await this.downloadFileContent(
            repo,
            skirYmlFile.sha,
          );
          const config = yaml.parse(skirYmlContent);
          dependencies = config?.dependencies || {};
        } catch {
          // If skir.yml doesn't exist or is malformed, just use empty dependencies
          dependencies = {};
        }
      }

      return {
        success: true,
        package: {
          packageId,
          version,
          modules,
          dependencies,
        },
      };
    } catch (error) {
      return {
        success: false,
        error: `Failed to download package ${packageId}@${version}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      };
    }
  }

  private packageIdToRepo(packageId: string): string {
    // Convert "@foo/bar" to "foo/bar"
    if (packageId.startsWith("@")) {
      return packageId.substring(1);
    }
    return packageId;
  }

  private async getGithubTree(
    repo: string,
    version: string,
  ): Promise<GitHubTree> {
    const url = `https://api.github.com/repos/${repo}/git/trees/${version}?recursive=1`;
    const headers: Record<string, string> = {
      Accept: "application/vnd.github.v3+json",
    };

    if (this.githubToken) {
      headers.Authorization = `token ${this.githubToken}`;
    }

    const response = await fetch(url, { headers });

    if (!response.ok) {
      throw new Error(
        `GitHub API request failed: ${response.status} ${response.statusText}`,
      );
    }

    return (await response.json()) as GitHubTree;
  }

  private async downloadFileContent(
    repo: string,
    sha: string,
  ): Promise<string> {
    const url = `https://api.github.com/repos/${repo}/git/blobs/${sha}`;
    const headers: Record<string, string> = {
      Accept: "application/vnd.github.v3+json",
    };

    if (this.githubToken) {
      headers.Authorization = `token ${this.githubToken}`;
    }

    const response = await fetch(url, { headers });

    if (!response.ok) {
      throw new Error(
        `Failed to download file: ${response.status} ${response.statusText}`,
      );
    }

    const data = (await response.json()) as {
      encoding: string;
      content: string;
    };

    // GitHub API returns base64 encoded content
    if (data.encoding === "base64") {
      return Buffer.from(data.content, "base64").toString("utf-8");
    }

    return data.content;
  }
}
