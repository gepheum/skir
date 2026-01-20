import { parseSkirConfig } from "./config_parser.js";
import { formatSkirConfigError } from "./error_renderer.js";
import type {
  DependencyError,
  DownloadPackageResult,
} from "./package_types.js";

/** Downloads a package from Github. */
export async function downloadPackage(
  packageId: string,
  version: string,
  githubToken: string | undefined,
): Promise<DownloadPackageResult> {
  // Convert package ID like "@foo/bar" to Github repo "foo/bar"
  const repo = packageId.substring(1);

  // Get the repository tree for the specific version
  const treeResult = await getGithubTree(repo, version, githubToken);
  if (treeResult.kind === "error") {
    return treeResult;
  }
  const tree = treeResult.tree;

  // Find all .skir files in the skir-src directory
  const skirFiles = tree.tree.filter(
    (item) =>
      item.type === "blob" &&
      item.path.startsWith("skir-src/") &&
      item.path.endsWith(".skir"),
  );

  // Download the content of each .skir file in parallel
  const modules: { [modulePath: string]: string } = {};
  const downloadPromises = skirFiles.map(async (file) => {
    const content = await downloadFileContent(repo, file.sha, githubToken);
    // Get relative path from skir-src/
    const modulePath = packageId + file.path.substring("skir-src".length);
    return { modulePath, content };
  });

  const downloadedFiles = await Promise.all(downloadPromises);
  for (const { modulePath, content } of downloadedFiles) {
    modules[modulePath] = content;
  }

  // Download and parse skir.yml for dependencies
  const skirYmlFile = tree.tree.find(
    (item) => item.type === "blob" && item.path === "skir.yml",
  );

  if (!skirYmlFile) {
    return {
      kind: "error",
      message: `Package ${packageId}@${version} is missing required skir.yml configuration file`,
    };
  }

  const skirYmlContent = await downloadFileContent(
    repo,
    skirYmlFile.sha,
    githubToken,
  );
  const configResult = parseSkirConfig(skirYmlContent);
  if (configResult.errors.length > 0) {
    return {
      kind: "error",
      message: configResult.errors
        .map((e) =>
          formatSkirConfigError(e, {
            skirConfigPath: `${packageId}/skir.yml`,
          }),
        )
        .join("\n"),
    };
  }
  const dependencies = configResult.skirConfig!.dependencies;
  return {
    kind: "success",
    package: {
      packageId,
      version,
      modules,
      dependencies,
    },
  };
}

async function getGithubTree(
  repo: string,
  version: string,
  githubToken?: string,
): Promise<GithubTreeResult> {
  const url = `https://api.github.com/repos/${repo}/git/trees/${version}?recursive=1`;
  const response = await fetch(url, { headers: makeHeaders(githubToken) });

  if (!response.ok) {
    if (response.status === 404) {
      // Check if the repo exists or if it's the tag that's missing
      const repoCheckUrl = `https://api.github.com/repos/${repo}`;
      const repoResponse = await fetch(repoCheckUrl, {
        headers: makeHeaders(githubToken),
      });

      if (repoResponse.ok) {
        // Repo exists, so the tag is missing
        return {
          kind: "error",
          message: `Version not found: https://github.com/${repo}/releases/tag/${version}`,
        };
      } else {
        // Repo doesn't exist
        return {
          kind: "error",
          message: `Repository not found: https://github.com/${repo}`,
        };
      }
    } else {
      throw new Error(
        `Github API request failed: ${response.status} ${response.statusText}`,
      );
    }
  }

  const githubTree = (await response.json()) as GithubTree;
  return {
    kind: "success",
    tree: githubTree,
  };
}

async function downloadFileContent(
  repo: string,
  sha: string,
  githubToken?: string,
): Promise<string> {
  const url = `https://api.github.com/repos/${repo}/git/blobs/${sha}`;
  const response = await fetch(url, { headers: makeHeaders(githubToken) });

  if (!response.ok) {
    throw new Error(
      `Failed to download file: ${response.status} ${response.statusText}`,
    );
  }

  const data = (await response.json()) as {
    encoding: string;
    content: string;
  };

  // Github API returns base64 encoded content
  if (data.encoding === "base64") {
    return Buffer.from(data.content, "base64").toString("utf-8");
  }

  return data.content;
}

function makeHeaders(githubToken?: string): Record<string, string> {
  const headers: Record<string, string> = {
    Accept: "application/vnd.github.v3+json",
  };

  if (githubToken) {
    headers.Authorization = `token ${githubToken}`;
  }

  return headers;
}

interface GithubTreeItem {
  path: string;
  mode: string;
  type: "blob" | "tree";
  sha: string;
  size?: number;
  url: string;
}

interface GithubTree {
  sha: string;
  url: string;
  tree: GithubTreeItem[];
  truncated: boolean;
}

type GithubTreeResult =
  | {
      kind: "success";
      tree: GithubTree;
    }
  | DependencyError;
