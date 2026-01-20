export type PackageIdToVersion = Readonly<{
  [packageId: string]: string;
}>;

export type DependenciesResult =
  | {
      kind: "success";
      packages: ReadonlyPackages;
      /// Whether the dependencies have changed since last time.
      changed: boolean;
    }
  | DependencyError;

export type Packages = { [packageId: string]: Package };
export type ReadonlyPackages = Readonly<Packages>;

export interface Package {
  readonly packageId: string;
  readonly version: string;
  readonly modules: Readonly<{ [modulePath: string]: string }>;
  readonly dependencies: PackageIdToVersion;
}

export interface DependencyError {
  kind: "error";
  message: string;
}

export type DownloadPackageResult =
  | {
      kind: "success";
      package: Package;
    }
  | DependencyError;

export type PackageDownloader = (
  packageId: string,
  version: string,
  githubToken: string | undefined,
) => Promise<DownloadPackageResult>;
