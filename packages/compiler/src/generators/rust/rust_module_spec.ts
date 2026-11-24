import { Module } from "skir-internal";

export interface RustModuleSpec {
  readonly path: string;
  /** These child modules must be declared in this module with `pub mod`. */
  readonly childModuleNames: ReadonlySet<string>;
  /**
   * Not set if this module is only a "gateway" to modules defined in a
   * subdirectory.
   */
  readonly skirModule: Module | null;
}

/**
 * Derives the full set of Rust module specs from a list of skir modules,
 * including any intermediate "gateway" modules needed to bridge directory gaps.
 */
export function collectRustModuleSpecs(
  skirModules: readonly Module[],
): readonly RustModuleSpec[] {
  const pathToModuleSpec = new Map<string, MutableRustModuleSpec>();
  for (const skirModule of skirModules) {
    const rustModulePath = "base/".concat(
      skirModule.path
        .replace(/^@/, "external/")
        .replace(/-/g, "_")
        .replace(/\.skir$/, ".rs"),
    );
    // Upsert the spec for this module's own .rs file.
    {
      const moduleSpec = pathToModuleSpec.get(rustModulePath);
      if (moduleSpec) {
        moduleSpec.skirModule = skirModule;
      } else {
        pathToModuleSpec.set(rustModulePath, {
          path: rustModulePath,
          childModuleNames: new Set<string>(),
          skirModule: skirModule,
        });
      }
    }

    // Walk up the path, registering each ancestor as a gateway module and
    // recording child declarations, until we reach an already-known ancestor.
    let child = rustModulePath;
    const parts = rustModulePath.split("/");
    for (let i = 1; i < parts.length; i++) {
      const parentPath = parts.slice(0, -i).join("/").concat(".rs");
      const parentSpec = pathToModuleSpec.get(parentPath);
      const childModuleName = child.replace(/.*\//, "").replace(/\.rs$/, "");
      if (parentSpec) {
        parentSpec.childModuleNames.add(childModuleName);
        // No need to go on.
        break;
      } else {
        pathToModuleSpec.set(parentPath, {
          path: parentPath,
          childModuleNames: new Set([childModuleName]),
          skirModule: null,
        });
      }
      child = parentPath;
    }
  }
  return [...pathToModuleSpec.values()];
}

interface MutableRustModuleSpec {
  readonly path: string;
  childModuleNames: Set<string>;
  skirModule: Module | null;
}
