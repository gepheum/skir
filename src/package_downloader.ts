import { LineCounter, parseDocument, Scalar, YAMLMap } from "yaml";
import { z } from "zod";
import type {
  SkirConfigError,
  SkirConfigErrorPos,
  SkirConfigErrorRange,
} from "./config_parser.js";
import { formatSkirConfigError } from "./error_renderer.js";
import type {
  DependencyError,
  DownloadPackageResult,
  PackageIdToVersion,
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
  const configResult = parseDependenciesConfig(skirYmlContent);
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
  const dependencies = configResult.dependencies ?? {};
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

async function fetchWithRetry(
  url: string,
  headers: Record<string, string>,
  maxRetries = 3,
): Promise<Response> {
  let lastResponse: Response | undefined;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    const response = await fetch(url, { headers });
    if (response.status !== 403 && response.status !== 429) {
      return response;
    }
    lastResponse = response;
    if (attempt === maxRetries) {
      break;
    }
    const retryAfter = response.headers.get("Retry-After");
    const waitMs = retryAfter
      ? parseInt(retryAfter, 10) * 1000
      : 1000 * 2 ** attempt;
    await new Promise((resolve) => setTimeout(resolve, waitMs));
  }
  return lastResponse!;
}

async function getGithubTree(
  repo: string,
  version: string,
  githubToken?: string,
): Promise<GithubTreeResult> {
  const url = `https://api.github.com/repos/${repo}/git/trees/${version}?recursive=1`;
  const response = await fetchWithRetry(url, makeHeaders(githubToken));

  if (!response.ok) {
    if (response.status === 404) {
      // Check if the repo exists or if it's the tag that's missing
      const repoCheckUrl = `https://api.github.com/repos/${repo}`;
      const repoResponse = await fetchWithRetry(
        repoCheckUrl,
        makeHeaders(githubToken),
      );

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
  const response = await fetchWithRetry(url, makeHeaders(githubToken));

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
    return decodeBase64Utf8(data.content);
  }

  return data.content;
}

function decodeBase64Utf8(base64: string): string {
  const normalized = base64.replace(/\s/g, "");
  const binary = atob(normalized);
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

// We intentionally keep this parser local to avoid importing the full
// config parser stack (which drags Node-only generator packages) when
// dependency download is used from browser-safe entry points.
type DependenciesConfigError = {
  message: SkirConfigError["message"];
  range?: DependenciesConfigErrorRange;
};

type DependenciesConfigErrorRange = SkirConfigErrorRange;
type DependenciesConfigErrorPos = SkirConfigErrorPos;

const PackageId = z.string().regex(/^@[A-Za-z0-9-]+\/[A-Za-z0-9\-_.]+$/);
const Version = z.string().regex(/^[A-Za-z0-9\-_./+]+$/);

const DependenciesOnlyConfig = z.object({
  dependencies: z.record(PackageId, Version).default({}),
});

function parseDependenciesConfig(yamlCode: string): {
  dependencies: PackageIdToVersion | undefined;
  errors: readonly DependenciesConfigError[];
} {
  const errors: DependenciesConfigError[] = [];

  const lineCounter = new LineCounter();
  const doc = parseDocument(yamlCode, { lineCounter });

  const offsetToPos = (offset: number): DependenciesConfigErrorPos => {
    const pos = lineCounter.linePos(offset);
    return {
      offset,
      lineNumber: pos.line,
      colNumber: pos.col,
    };
  };

  const offsetRangeToRange = (
    start: number,
    end: number,
  ): DependenciesConfigErrorRange => ({
    start: offsetToPos(start),
    end: offsetToPos(end),
  });

  const pathToRange = (
    path: readonly PropertyKey[],
  ): DependenciesConfigErrorRange | undefined => {
    const node = doc.getIn(path, true) as Scalar | YAMLMap | undefined;
    if (!node?.range) {
      return undefined;
    }
    return offsetRangeToRange(node.range[0], node.range[1]);
  };

  const pushErrorAtPath = (
    originalPath: readonly PropertyKey[],
    message: string,
  ): void => {
    let path = originalPath;
    const pathRemainder: PropertyKey[] = [];
    while (path.length !== 0) {
      const range = pathToRange(path);
      if (range) {
        break;
      }
      pathRemainder.push(path.at(-1)!);
      path = path.slice(0, -1);
    }
    pathRemainder.reverse();
    const pathRemainderStr = pathRemainder
      .map((part, index) =>
        typeof part === "number"
          ? `[${part}]`
          : index === 0
            ? part
            : `.${String(part)}`,
      )
      .join("");
    const messagePrefix = pathRemainder.length
      ? `Missing property '${pathRemainderStr}': `
      : "";
    errors.push({
      message: messagePrefix + message,
      range: pathToRange(path),
    });
  };

  if (doc.errors.length > 0) {
    for (const error of doc.errors) {
      errors.push({
        message: error.message,
        range: offsetRangeToRange(error.pos[0], error.pos[1]),
      });
    }
    return { dependencies: undefined, errors };
  }

  const parsed = DependenciesOnlyConfig.safeParse(doc.toJS());
  if (!parsed.success) {
    for (const issue of parsed.error.issues) {
      pushErrorAtPath(issue.path, issue.message);
    }
    return { dependencies: undefined, errors };
  }

  return {
    dependencies: parsed.data.dependencies,
    errors,
  };
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
