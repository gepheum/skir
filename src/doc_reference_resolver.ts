import {
  Constant,
  ErrorSink,
  ExpectedName,
  Method,
  Module,
  MutableConstant,
  MutableDoc,
  MutableDocReference,
  MutableDocReferenceName,
  MutableMethod,
  MutableRecord,
  MutableRecordField,
  Record,
  RecordField,
  RecordKey,
  RecordLocation,
  ResolvedType,
  SkirError,
} from "skir-internal";
import {
  declarationsToExpectedNames,
  ExpectedNamesCollector,
} from "./completion_helper.js";

export type Documentee =
  | MutableConstant
  | MutableMethod
  | MutableRecord
  | MutableRecordField;

/** Resolve the references in the doc comments of the given declaration. */
export function resolveDocReferences(
  documentee: Documentee,
  docModule: Module,
  getModule: (modulePath: string) => Module | undefined,
  recordMap: ReadonlyMap<RecordKey, RecordLocation>,
  errors: ErrorSink,
): void {
  const doc: MutableDoc =
    documentee.kind === "field" ? documentee.field.doc : documentee.doc;

  const docReferences = doc.pieces.filter(
    (p): p is MutableDocReference => p.kind === "reference",
  );
  if (docReferences.length <= 0) {
    return;
  }

  // Build list of naming scopes to search, in order of priority.
  const scopes = buildScopes(documentee, docModule, recordMap);

  // Resolve each reference by searching through scopes in priority order.
  for (const reference of docReferences) {
    resolveReferenceInScopes(reference, scopes, docModule, getModule, errors);
  }
}

function buildScopes(
  documentee: Documentee,
  docModule: Module,
  recordMap: ReadonlyMap<RecordKey, RecordLocation>,
): Array<Record | Module> {
  const scopes: Array<Record | Module> = [];
  const pushRecordAncestorsToScopes = (record: Record): void => {
    const { key } = record;
    const location = recordMap.get(key)!;
    const ancestors = [...location.recordAncestors].reverse();
    for (const ancestor of ancestors) {
      scopes.push(ancestor);
    }
  };
  const pushTypeToScopes = (type: ResolvedType | undefined): void => {
    if (type) {
      const recordKey = tryFindRecordForType(type);
      if (recordKey) {
        const { record } = recordMap.get(recordKey)!;
        scopes.push(record);
      }
    }
  };
  switch (documentee.kind) {
    case "constant": {
      scopes.push(docModule);
      pushTypeToScopes(documentee.type);
      break;
    }
    case "field": {
      const { field, record } = documentee;
      pushRecordAncestorsToScopes(record);
      scopes.push(docModule);
      pushTypeToScopes(field.type);
      break;
    }
    case "method": {
      scopes.push(docModule);
      pushTypeToScopes(documentee.requestType);
      pushTypeToScopes(documentee.responseType);
      break;
    }
    case "record": {
      pushRecordAncestorsToScopes(documentee);
      scopes.push(docModule);
      break;
    }
  }
  return scopes;
}

function resolveReferenceInScopes(
  reference: MutableDocReference,
  scopes: ReadonlyArray<Record | Module>,
  docModule: Module,
  getModule: (modulePath: string) => Module | undefined,
  errors: ErrorSink,
): void {
  const { nameParts } = reference;
  if (nameParts.length <= 0) {
    return;
  }
  const expectedNamesCollector = new ExpectedNamesCollector();
  for (const scope of scopes) {
    if (reference.absolute && scope !== docModule) {
      continue;
    }
    const referee = tryResolveReference(nameParts, scope, docModule, getModule);
    if (referee.kind === "no-match") {
      expectedNamesCollector.collect(referee.expectedNames);
      // Try the next scope.
    } else if (referee.kind === "failed-match") {
      if (referee.error) {
        errors.push(referee.error);
      }
      // Don't try the next scope.
      return;
    } else {
      reference.referee = referee;
      return;
    }
  }
  // No match in any scope. Report an error on the first name part.
  const firstName = nameParts[0]!.token;
  errors.push({
    token: firstName,
    message: "Not found",
    expectedNames: expectedNamesCollector.expectedNames,
  });
}

type NoMatch = {
  readonly kind: "no-match";
  /** Expectations for the first name in the chain. */
  readonly expectedNames: readonly ExpectedName[];
};

type FailedMatch = {
  readonly kind: "failed-match";
  readonly error: SkirError | null;
};

// Try to resolve a reference by looking it up in the given scope.
function tryResolveReference(
  nameParts: readonly MutableDocReferenceName[],
  scope: Record | Module,
  docModule: Module,
  getModule: (modulePath: string) => Module | undefined,
): Record | Method | Constant | RecordField | NoMatch | FailedMatch {
  let firstNameMatched = false;
  for (let i = 0; i < nameParts.length; i++) {
    const namePart = nameParts[i]!;
    const match = scope.nameToDeclaration[namePart.token.text];
    if (!match) {
      const expectedNames = declarationsToExpectedNames(
        scope.nameToDeclaration,
        (d) =>
          scope === docModule ||
          (d.kind !== "import" && d.kind !== "import-alias"),
      );
      if (firstNameMatched) {
        return {
          kind: "failed-match",
          error: {
            token: namePart.token,
            message: "Not found",
            expectedNames: expectedNames,
          },
        };
      } else {
        return {
          kind: "no-match",
          expectedNames: expectedNames,
        };
      }
    }
    firstNameMatched = true;
    const isLastPart = i === nameParts.length - 1;
    if (isLastPart) {
      switch (match.kind) {
        case "constant":
        case "method":
        case "record": {
          namePart.declaration = match;
          return match;
        }
        case "field": {
          namePart.declaration = match;
          return {
            kind: "field",
            field: match,
            record: scope as Record,
          };
        }
        case "import":
        case "import-alias":
        case "removed": {
          return {
            kind: "failed-match",
            error: {
              token: namePart.token,
              message: "Cannot be the last name in the sequence",
            },
          };
        }
      }
    } else {
      switch (match.kind) {
        case "record": {
          scope = match;
          namePart.declaration = match;
          break;
        }
        case "import":
        case "import-alias": {
          if (scope !== docModule) {
            // Cannot refer to other module's imports.
            return {
              kind: "failed-match",
              error: {
                token: namePart.token,
                message: "Cannot refer to other module's imports",
              },
            };
          }
          const { resolvedModulePath } = match;
          if (!resolvedModulePath) {
            return {
              kind: "failed-match",
              error: null, // An error has already been registered
            };
          }
          const importedModule = getModule(resolvedModulePath!);
          if (!importedModule) {
            return {
              kind: "failed-match",
              error: null, // An error has already been registered
            };
          }
          scope = importedModule;
          if (match.kind === "import") {
            // Rewind to this name part, but with the imported module as scope.
            --i;
          } else {
            namePart.declaration = match;
          }
          break;
        }
        case "constant":
        case "method":
        case "field":
        case "removed": {
          return {
            kind: "failed-match",
            error: {
              token: namePart.token,
              message: "Expected to be the last name in the sequence",
            },
          };
        }
      }
    }
  }
  throw new Error("Unreachable");
}

function tryFindRecordForType(type: ResolvedType): RecordKey | null {
  switch (type.kind) {
    case "array":
      return tryFindRecordForType(type.item);
    case "optional":
      return tryFindRecordForType(type.other);
    case "record":
      return type.key;
    case "primitive":
      return null;
  }
}
