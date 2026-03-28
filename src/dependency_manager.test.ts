import { expect } from "buckwheat";
import { describe, it } from "node:test";
import {
  DependencyManager,
  getModuleFromGithubUrl,
} from "./dependency_manager.js";
import type { AsyncFileReader } from "./io.js";
import type {
  DownloadPackageResult,
  Package,
  Packages,
} from "./package_types.js";

class FakeAsyncFileReader implements AsyncFileReader {
  private readonly files = new Map<string, string>();

  setFile(path: string, content: string): void {
    this.files.set(path, content);
  }

  async readTextFileAsync(path: string): Promise<string | undefined> {
    return this.files.get(path);
  }
}

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

describe("DependencyManager", () => {
  it("returns empty packages when no dependencies requested", async () => {
    const fileReader = new FakeAsyncFileReader();
    const downloader = new FakePackageDownloader();
    const manager = new DependencyManager(
      "/test/root",
      undefined,
      fileReader,
      downloader.downloadPackage,
    );

    const result = await manager.getDependencies({}, "no-write");

    expect(result).toMatch({
      kind: "success",
      packages: {},
      changed: false,
    });
  });

  it("downloads a single package successfully", async () => {
    const fileReader = new FakeAsyncFileReader();
    const downloader = new FakePackageDownloader();

    const pkg: Package = {
      packageId: "@org/pkg",
      version: "v1.0.0",
      modules: {
        "@org/pkg/module.skir": "struct Foo {}",
      },
      dependencies: {},
    };

    downloader.setPackage("@org/pkg", "v1.0.0", pkg);

    const manager = new DependencyManager(
      "/test/root",
      undefined,
      fileReader,
      downloader.downloadPackage,
    );

    const result = await manager.getDependencies(
      { "@org/pkg": "v1.0.0" },
      "no-write",
    );

    expect(result).toMatch({
      kind: "success",
      packages: {
        "@org/pkg": pkg,
      },
      changed: true,
    });
  });

  it("downloads transitive dependencies", async () => {
    const fileReader = new FakeAsyncFileReader();
    const downloader = new FakePackageDownloader();

    const pkgA: Package = {
      packageId: "@org/pkg-a",
      version: "v1.0.0",
      modules: {
        "@org/pkg-a/module.skir": "struct A {}",
      },
      dependencies: {
        "@org/pkg-b": "v2.0.0",
      },
    };

    const pkgB: Package = {
      packageId: "@org/pkg-b",
      version: "v2.0.0",
      modules: {
        "@org/pkg-b/module.skir": "struct B {}",
      },
      dependencies: {},
    };

    downloader.setPackage("@org/pkg-a", "v1.0.0", pkgA);
    downloader.setPackage("@org/pkg-b", "v2.0.0", pkgB);

    const manager = new DependencyManager(
      "/test/root",
      undefined,
      fileReader,
      downloader.downloadPackage,
    );

    const result = await manager.getDependencies(
      { "@org/pkg-a": "v1.0.0" },
      "no-write",
    );

    expect(result).toMatch({
      kind: "success",
      packages: {
        "@org/pkg-a": pkgA,
        "@org/pkg-b": pkgB,
      },
      changed: true,
    });
  });

  it("uses cached dependencies when available", async () => {
    const fileReader = new FakeAsyncFileReader();
    const downloader = new FakePackageDownloader();

    const cachedPackages: Packages = {
      "@org/pkg": {
        packageId: "@org/pkg",
        version: "v1.0.0",
        modules: {
          "@org/pkg/module.skir": "struct Foo {}",
        },
        dependencies: {},
      },
    };

    fileReader.setFile(
      "/test/root/skir-external/dependencies.json",
      JSON.stringify(cachedPackages),
    );

    const manager = new DependencyManager(
      "/test/root",
      undefined,
      fileReader,
      downloader.downloadPackage,
    );

    const result = await manager.getDependencies(
      { "@org/pkg": "v1.0.0" },
      "no-write",
    );

    expect(result).toMatch({
      kind: "success",
      packages: cachedPackages,
      changed: false,
    });
  });

  it("returns error when package download fails", async () => {
    const fileReader = new FakeAsyncFileReader();
    const downloader = new FakePackageDownloader();

    const manager = new DependencyManager(
      "/test/root",
      undefined,
      fileReader,
      downloader.downloadPackage,
    );

    const result = await manager.getDependencies(
      { "@org/missing": "v1.0.0" },
      "no-write",
    );

    expect(result).toMatch({
      kind: "error",
      message: "Package @org/missing@v1.0.0 not found",
    });
  });

  it("detects version conflicts", async () => {
    const fileReader = new FakeAsyncFileReader();
    const downloader = new FakePackageDownloader();

    const pkgA: Package = {
      packageId: "@org/pkg-a",
      version: "v1.0.0",
      modules: {},
      dependencies: {
        "@org/pkg-c": "v1.0.0",
      },
    };

    const pkgB: Package = {
      packageId: "@org/pkg-b",
      version: "v1.0.0",
      modules: {},
      dependencies: {
        "@org/pkg-c": "v2.0.0",
      },
    };

    const pkgC1: Package = {
      packageId: "@org/pkg-c",
      version: "v1.0.0",
      modules: {},
      dependencies: {},
    };

    const pkgC2: Package = {
      packageId: "@org/pkg-c",
      version: "v2.0.0",
      modules: {},
      dependencies: {},
    };

    downloader.setPackage("@org/pkg-a", "v1.0.0", pkgA);
    downloader.setPackage("@org/pkg-b", "v1.0.0", pkgB);
    downloader.setPackage("@org/pkg-c", "v1.0.0", pkgC1);
    downloader.setPackage("@org/pkg-c", "v2.0.0", pkgC2);

    const manager = new DependencyManager(
      "/test/root",
      undefined,
      fileReader,
      downloader.downloadPackage,
    );

    const result = await manager.getDependencies(
      {
        "@org/pkg-a": "v1.0.0",
        "@org/pkg-b": "v1.0.0",
      },
      "no-write",
    );

    expect(result.kind).toMatch("error");
    if (result.kind === "error") {
      expect(result.message.includes("Version conflict")).toMatch(true);
      expect(result.message.includes("@org/pkg-c")).toMatch(true);
    }
  });

  it("handles complex dependency graph", async () => {
    const fileReader = new FakeAsyncFileReader();
    const downloader = new FakePackageDownloader();

    // Diamond dependency:
    // A depends on B and C
    // B depends on D
    // C depends on D
    // All should resolve to same D version

    const pkgA: Package = {
      packageId: "@org/a",
      version: "v1.0.0",
      modules: {},
      dependencies: {
        "@org/b": "v1.0.0",
        "@org/c": "v1.0.0",
      },
    };

    const pkgB: Package = {
      packageId: "@org/b",
      version: "v1.0.0",
      modules: {},
      dependencies: {
        "@org/d": "v1.0.0",
      },
    };

    const pkgC: Package = {
      packageId: "@org/c",
      version: "v1.0.0",
      modules: {},
      dependencies: {
        "@org/d": "v1.0.0",
      },
    };

    const pkgD: Package = {
      packageId: "@org/d",
      version: "v1.0.0",
      modules: {},
      dependencies: {},
    };

    downloader.setPackage("@org/a", "v1.0.0", pkgA);
    downloader.setPackage("@org/b", "v1.0.0", pkgB);
    downloader.setPackage("@org/c", "v1.0.0", pkgC);
    downloader.setPackage("@org/d", "v1.0.0", pkgD);

    const manager = new DependencyManager(
      "/test/root",
      undefined,
      fileReader,
      downloader.downloadPackage,
    );

    const result = await manager.getDependencies(
      { "@org/a": "v1.0.0" },
      "no-write",
    );

    expect(result).toMatch({
      kind: "success",
      packages: {
        "@org/a": pkgA,
        "@org/b": pkgB,
        "@org/c": pkgC,
        "@org/d": pkgD,
      },
      changed: true,
    });
  });

  it("detects changed flag correctly when cache has different packages", async () => {
    const fileReader = new FakeAsyncFileReader();
    const downloader = new FakePackageDownloader();

    const cachedPackages: Packages = {
      "@org/old": {
        packageId: "@org/old",
        version: "v1.0.0",
        modules: {},
        dependencies: {},
      },
    };

    fileReader.setFile(
      "/test/root/skir-external/dependencies.json",
      JSON.stringify(cachedPackages),
    );

    const newPkg: Package = {
      packageId: "@org/new",
      version: "v1.0.0",
      modules: {},
      dependencies: {},
    };

    downloader.setPackage("@org/new", "v1.0.0", newPkg);

    const manager = new DependencyManager(
      "/test/root",
      undefined,
      fileReader,
      downloader.downloadPackage,
    );

    const result = await manager.getDependencies(
      { "@org/new": "v1.0.0" },
      "no-write",
    );

    expect(result).toMatch({ kind: "success", changed: true });
  });

  it("handles malformed cached dependencies file", async () => {
    const fileReader = new FakeAsyncFileReader();
    const downloader = new FakePackageDownloader();

    fileReader.setFile(
      "/test/root/skir-external/dependencies.json",
      "{ invalid json",
    );

    const pkg: Package = {
      packageId: "@org/pkg",
      version: "v1.0.0",
      modules: {},
      dependencies: {},
    };

    downloader.setPackage("@org/pkg", "v1.0.0", pkg);

    const manager = new DependencyManager(
      "/test/root",
      undefined,
      fileReader,
      downloader.downloadPackage,
    );

    const result = await manager.getDependencies(
      { "@org/pkg": "v1.0.0" },
      "no-write",
    );

    // Should still work, just treat cache as empty
    expect(result).toMatch({
      kind: "success",
      packages: { "@org/pkg": pkg },
      changed: true,
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

      expect(result.kind).toMatch("success");
      if (result.kind === "success") {
        expect(result.record.name).toMatch({
          text: "Spell",
          line: {
            modulePath: "@gepheum/skir-fantasy-game-example/fantasy_game.skir",
          },
        });
      }
    }
  });
});
