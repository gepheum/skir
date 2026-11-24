import type { Declaration, ExpectedName, Removed } from "skir-internal";

export function declarationsToExpectedNames(
  nameToDeclaration: { [name: string]: Declaration },
  predicate: (value: Exclude<Declaration, Removed>) => boolean,
): readonly ExpectedName[] {
  const result: ExpectedName[] = [];
  for (const [name, declaration] of Object.entries(nameToDeclaration)) {
    if (declaration.kind === "removed" || !predicate(declaration)) {
      continue;
    }
    const doc =
      declaration.kind !== "import" && declaration.kind !== "import-alias"
        ? declaration.doc
        : undefined;
    result.push({ name, doc });
  }
  return result;
}

export class ExpectedNamesCollector {
  private readonly expectedNamesData: ExpectedName[] = [];
  private readonly expectedNameSet = new Set<string>();

  collect(expectedNames: readonly ExpectedName[]): void {
    for (const expectedName of expectedNames) {
      if (expectedName.modulePath) {
        this.expectedNamesData.push(expectedName);
      } else if (!this.expectedNameSet.has(expectedName.name)) {
        this.expectedNamesData.push(expectedName);
        this.expectedNameSet.add(expectedName.name);
      }
    }
  }

  get expectedNames(): readonly ExpectedName[] {
    return this.expectedNamesData;
  }
}
