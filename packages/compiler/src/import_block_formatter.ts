import { ImportedNames, PathToImportedNames } from "skir-internal";

export function formatImportBlock(
  pathToImportedNames: Readonly<PathToImportedNames>,
): string {
  const formatImport = (import_: [string, ImportedNames]): string => {
    const [path, names] = import_;
    const quotedPath = JSON.stringify(path);
    if (names.kind === "all") {
      return `import * as ${names.alias} from ${quotedPath};`;
    } else if (names.names.size <= 0) {
      return "";
    } else if (names.names.size === 1) {
      const name = [...names.names][0];
      return `import { ${name} } from ${quotedPath};`;
    } else {
      const nameLines = [...names.names].sort().map((name) => `  ${name},\n`);
      return `import {\n${nameLines.join("")}} from ${quotedPath};`;
    }
  };

  const formatImports = (imports: Array<[string, ImportedNames]>): string => {
    imports.sort(([pathA], [pathB]) => pathA.localeCompare(pathB, "en-US"));
    return imports
      .map(formatImport)
      .filter((it) => it)
      .join("\n");
  };

  const imports = Object.entries(pathToImportedNames);

  return [
    imports.filter(([path, _]) => path.startsWith("@")),
    imports.filter(([path, _]) => !path.startsWith("@")),
  ]
    .map(formatImports)
    .filter((it) => it)
    .join("\n\n");
}
