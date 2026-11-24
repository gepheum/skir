import { expect } from "buckwheat";
import { describe, it } from "node:test";
import {
  getModuleFromGithubUrl,
  parseGithubModuleUrl,
} from "./get_dependencies_flow.js";
import type { DownloadPackageResult, Package } from "./package_types.js";

class FakePackageDownloader {
  private readonly packages = new Map<string, Package>();

  setPackage(packageId: string, version: string, pkg: Package): void {
    const key = `${packageId}@${version}`;
    this.packages.set(key, pkg);
  }

  downloadPackage = async (
    packageId: string,
    version: string,
    _githubToken?: string,
  ): Promise<DownloadPackageResult> => {
    const key = `${packageId}@${version}`;
    const pkg = this.packages.get(key);
    if (pkg) {
      return {
        kind: "success",
        package: pkg,
      };
    }
    return {
      kind: "error",
      message: `Package ${packageId}@${version} not found`,
    };
  };
}

describe("parseGithubModuleUrl", () => {
  it("parses a valid GitHub blob URL", () => {
    expect(
      parseGithubModuleUrl(
        "https://github.com/org/repo/blob/main/skir-src/example.skir#L2",
      ),
    ).toMatch({
      kind: "success",
      packageId: "@org/repo",
      version: "main",
      modulePath: "@org/repo/example.skir",
      lineNumber: 1,
    });
  });

  it("rejects URLs outside skir-src", () => {
    expect(
      parseGithubModuleUrl(
        "https://github.com/org/repo/blob/main/src/example.skir#L2",
      ),
    ).toMatch({
      kind: "error",
      message:
        "URL must target a .skir file in skir-src: https://github.com/org/repo/blob/main/src/example.skir#L2",
    });
  });

  it("rejects URLs that do not point to .skir files", () => {
    expect(
      parseGithubModuleUrl(
        "https://github.com/org/repo/blob/main/skir-src/example.ts#L2",
      ),
    ).toMatch({
      kind: "error",
      message:
        "URL must target a .skir file in skir-src: https://github.com/org/repo/blob/main/skir-src/example.ts#L2",
    });
  });

  it("rejects invalid line numbers", () => {
    expect(
      parseGithubModuleUrl(
        "https://github.com/org/repo/blob/main/skir-src/example.skir#L0",
      ),
    ).toMatch({
      kind: "error",
      message:
        "Invalid line number in URL: https://github.com/org/repo/blob/main/skir-src/example.skir#L0",
    });
  });

  it("rejects invalid GitHub URL shapes", () => {
    expect(
      parseGithubModuleUrl(
        "https://example.com/org/repo/blob/main/skir-src/example.skir#L2",
      ),
    ).toMatch({
      kind: "error",
      message:
        "Invalid GitHub URL: https://example.com/org/repo/blob/main/skir-src/example.skir#L2",
    });
  });
});

describe("getModuleFromGithubUrl", () => {
  it("returns the compiled record for a valid URL and matching record line", async () => {
    const downloader = new FakePackageDownloader();

    const pkg: Package = {
      packageId: "@org/repo",
      version: "main",
      modules: {
        "@org/repo/example.skir": [
          "struct First {}",
          "struct Target {}",
          "",
        ].join("\n"),
      },
      dependencies: {},
    };
    downloader.setPackage("@org/repo", "main", pkg);

    const result = await getModuleFromGithubUrl(
      "https://github.com/org/repo/blob/main/skir-src/example.skir#L2",
      undefined,
      downloader.downloadPackage,
    );

    expect(result.kind).toMatch("success");
    if (result.kind === "success") {
      expect(result.record.name.text).toMatch("Target");
      expect(result.record.name.line.modulePath).toMatch(
        "@org/repo/example.skir",
      );
    }
  });

  it("returns dependency errors from downloader", async () => {
    const downloader = new FakePackageDownloader();

    const result = await getModuleFromGithubUrl(
      "https://github.com/org/missing/blob/main/skir-src/example.skir#L1",
      undefined,
      downloader.downloadPackage,
    );

    expect(result).toMatch({
      kind: "error",
      message: "Package @org/missing@main not found",
    });
  });

  it("returns the first compile error when modules fail to compile", async () => {
    const downloader = new FakePackageDownloader();

    const brokenPkg: Package = {
      packageId: "@org/repo",
      version: "main",
      modules: {
        "@org/repo/example.skir": [
          'import * as missing from "./missing";',
          "struct Target {}",
          "",
        ].join("\n"),
      },
      dependencies: {},
    };
    downloader.setPackage("@org/repo", "main", brokenPkg);

    const result = await getModuleFromGithubUrl(
      "https://github.com/org/repo/blob/main/skir-src/example.skir#L2",
      undefined,
      downloader.downloadPackage,
    );

    expect(result.kind).toMatch("error");
    if (result.kind === "error") {
      expect(result.message).toMatch("Module not found");
    }
  });

  it("returns an error when no record starts on the requested line", async () => {
    const downloader = new FakePackageDownloader();

    const pkg: Package = {
      packageId: "@org/repo",
      version: "main",
      modules: {
        "@org/repo/example.skir": ["struct First {}", ""].join("\n"),
      },
      dependencies: {},
    };
    downloader.setPackage("@org/repo", "main", pkg);

    const result = await getModuleFromGithubUrl(
      "https://github.com/org/repo/blob/main/skir-src/example.skir#L2",
      undefined,
      downloader.downloadPackage,
    );

    expect(result).toMatch({
      kind: "error",
      message: "No record found at line 2 in @org/repo/example.skir",
    });
  });

  it("works in real life", async () => {
    const actuallyDownloadFromGithub = true;
    if (actuallyDownloadFromGithub) {
      const result = await getModuleFromGithubUrl(
        "https://github.com/gepheum/skir-fantasy-game-example/blob/v1.0.0/skir-src/fantasy_game.skir#L42",
        undefined,
      );

      expect(result).toMatch({
        kind: "success",
        record: {
          name: {
            text: "Spell",
            line: {
              modulePath:
                "@gepheum/skir-fantasy-game-example/fantasy_game.skir",
            },
          },
        },
        message: undefined,
      });
    }
  });
});
