/**
 * Utilities to help implement the jump-to-definition functionality for skir
 * files in IDEs.
 */
import {
  unquoteAndUnescape,
  type Constant,
  type Declaration,
  type Field,
  type ImportAlias,
  type Method,
  type Module,
  type Record,
  type ResolvedType,
  type Token,
  type Value,
} from "skir-internal";

export interface DefinitionMatch {
  modulePath: string;
  position: number;
  // Undefined if this definition match corresponds to a module path.
  declaration: Constant | Field | ImportAlias | Method | Record | undefined;
}

export function findDefinition(
  module: Module,
  position: number,
): DefinitionMatch | null {
  return findDefinitionInDeclarations(module.declarations, position);
}

function findDefinitionInDeclarations(
  declarations: readonly Declaration[],
  position: number,
): DefinitionMatch | null {
  for (const declaration of declarations) {
    const maybeMatch = findDefinitionInDeclaration(declaration, position);
    if (maybeMatch) {
      return maybeMatch;
    }
  }
  return null;
}

function findDefinitionInDeclaration(
  declaration: Declaration,
  position: number,
): DefinitionMatch | null {
  // First, look for a match in the doc comment.
  switch (declaration.kind) {
    case "import":
    case "import-alias":
    case "removed":
      // No doc.
      break;
    default: {
      for (const docPiece of declaration.doc.pieces) {
        if (docPiece.kind === "reference") {
          for (const namePart of docPiece.nameParts) {
            if (tokenContains(namePart.token, position)) {
              const { declaration } = namePart;
              if (declaration) {
                return declarationToMatch(declaration);
              } else {
                return null;
              }
            }
          }
        }
      }
    }
  }

  // If the position lands on the declaration's own name token, return it as
  // its own definition.
  switch (declaration.kind) {
    case "constant":
    case "field":
    case "import-alias":
    case "method":
    case "record": {
      if (tokenContains(declaration.name, position)) {
        return declarationToMatch(declaration);
      }
      break;
    }
  }

  // Then look for a match in the declaration itself.
  switch (declaration.kind) {
    case "constant": {
      if (declaration.type) {
        const maybeMatch = findDefinitionInResolvedType(
          declaration.type,
          position,
        );
        if (maybeMatch) {
          return maybeMatch;
        }
      }

      const maybeMatch = findDefinitionInValue(declaration.value, position);
      if (maybeMatch) {
        return maybeMatch;
      }

      return null;
    }
    case "field": {
      if (declaration.type) {
        return findDefinitionInResolvedType(declaration.type, position);
      }
      return null;
    }
    case "import":
    case "import-alias": {
      if (
        tokenContains(declaration.modulePath, position) &&
        declaration.resolvedModulePath
      ) {
        return {
          modulePath: declaration.resolvedModulePath,
          position: 0,
          declaration: undefined,
        };
      }
      return null;
    }
    case "method": {
      if (declaration.requestType) {
        const maybeMatch = findDefinitionInResolvedType(
          declaration.requestType,
          position,
        );
        if (maybeMatch) {
          return maybeMatch;
        }
      }
      if (declaration.responseType) {
        const maybeMatch = findDefinitionInResolvedType(
          declaration.responseType,
          position,
        );
        if (maybeMatch) {
          return maybeMatch;
        }
      }
      return null;
    }
    case "record": {
      return (
        findDefinitionInDeclarations(declaration.fields, position) ??
        findDefinitionInDeclarations(declaration.nestedRecords, position)
      );
    }
    case "removed": {
      return null;
    }
  }
}

function findDefinitionInResolvedType(
  type: ResolvedType,
  position: number,
): DefinitionMatch | null {
  switch (type.kind) {
    case "array": {
      if (type.key) {
        for (const item of type.key.path) {
          if (tokenContains(item.name, position)) {
            const { declaration } = item;
            if (declaration) {
              return declarationToMatch(declaration);
            }
          }
        }
      }
      return findDefinitionInResolvedType(type.item, position);
    }
    case "optional": {
      return findDefinitionInResolvedType(type.other, position);
    }
    case "primitive": {
      return null;
    }
    case "record": {
      for (const namePart of type.nameParts) {
        if (tokenContains(namePart.token, position)) {
          return declarationToMatch(namePart.declaration);
        }
      }
      return null;
    }
  }
}

function findDefinitionInValue(
  value: Value,
  position: number,
): DefinitionMatch | null {
  switch (value.kind) {
    case "array": {
      for (const item of value.items) {
        const maybeMatch = findDefinitionInValue(item, position);
        if (maybeMatch) {
          return maybeMatch;
        }
      }
      return null;
    }
    case "object": {
      if (!value.record) {
        return null;
      }
      if (value.record.recordType === "struct") {
        // Look for a match with a field name.
        for (const entry of Object.values(value.entries)) {
          if (tokenContains(entry.name, position)) {
            const { fieldDeclaration } = entry;
            if (fieldDeclaration) {
              return declarationToMatch(fieldDeclaration);
            } else {
              return null;
            }
          }
        }
      } else {
        // An enum. Look for a match with the "kind" field.
        const kindEntry = value.entries["kind"];
        if (kindEntry && kindEntry.value.kind === "literal") {
          if (tokenContains(kindEntry.value.token, position)) {
            const variantName = unquoteAndUnescape(kindEntry.value.token.text);
            const variantDeclaration =
              value.record.nameToDeclaration[variantName];
            if (variantDeclaration?.kind === "field") {
              return declarationToMatch(variantDeclaration);
            }
          } else {
            return null;
          }
        }
      }
      // Look for a match within the field values.
      for (const entry of Object.values(value.entries)) {
        const maybeMatch = findDefinitionInValue(entry.value, position);
        if (maybeMatch) {
          return maybeMatch;
        }
      }
      return null;
    }
    case "literal": {
      return null;
    }
  }
}

function tokenContains(token: Token, position: number): boolean {
  const end = token.position + token.text.length;
  return position >= token.position && position <= end;
}

function declarationToMatch(
  declaration: Constant | Field | ImportAlias | Method | Record,
): DefinitionMatch {
  const { name } = declaration;
  return {
    modulePath: name.line.modulePath,
    position: name.position,
    declaration: declaration,
  };
}

// -----------------------------------------------------------------------------
// REFERENCES FINDER
// -----------------------------------------------------------------------------

export function findReferences(
  definition: Token,
  modules: readonly Module[],
): Token[] {
  const references: Token[] = [];
  for (const module of modules) {
    findReferencesInDeclarations(definition, module.declarations, references);
  }
  return references;
}

function findReferencesInDeclarations(
  definition: Token,
  declarations: readonly Declaration[],
  references: Token[],
): void {
  for (const declaration of declarations) {
    findReferencesInDeclaration(definition, declaration, references);
  }
}

function findReferencesInDeclaration(
  definition: Token,
  declaration: Declaration,
  references: Token[],
): void {
  // First, collect references from the doc comment.
  switch (declaration.kind) {
    case "import":
    case "import-alias":
    case "removed":
      // No doc.
      break;
    default: {
      for (const docPiece of declaration.doc.pieces) {
        if (docPiece.kind === "reference") {
          for (const namePart of docPiece.nameParts) {
            if (namePart.declaration?.name === definition) {
              references.push(namePart.token);
            }
          }
        }
      }
    }
  }

  // Then collect references from the declaration body.
  switch (declaration.kind) {
    case "constant": {
      if (declaration.type) {
        findReferencesInResolvedType(definition, declaration.type, references);
      }
      findReferencesInValue(definition, declaration.value, references);
      break;
    }
    case "field": {
      if (declaration.type) {
        findReferencesInResolvedType(definition, declaration.type, references);
      }
      break;
    }
    case "import":
    case "import-alias": {
      // Module path tokens are not declaration references.
      break;
    }
    case "method": {
      if (declaration.requestType) {
        findReferencesInResolvedType(
          definition,
          declaration.requestType,
          references,
        );
      }
      if (declaration.responseType) {
        findReferencesInResolvedType(
          definition,
          declaration.responseType,
          references,
        );
      }
      break;
    }
    case "record": {
      findReferencesInDeclarations(definition, declaration.fields, references);
      break;
    }
    case "removed": {
      break;
    }
  }
}

function findReferencesInResolvedType(
  definition: Token,
  type: ResolvedType,
  references: Token[],
): void {
  switch (type.kind) {
    case "array": {
      if (type.key) {
        for (const item of type.key.path) {
          if (item.declaration?.name === definition) {
            references.push(item.name);
          }
        }
      }
      findReferencesInResolvedType(definition, type.item, references);
      break;
    }
    case "optional": {
      findReferencesInResolvedType(definition, type.other, references);
      break;
    }
    case "primitive": {
      break;
    }
    case "record": {
      for (const namePart of type.nameParts) {
        if (namePart.declaration.name === definition) {
          references.push(namePart.token);
        }
      }
      break;
    }
  }
}

function findReferencesInValue(
  definition: Token,
  value: Value,
  references: Token[],
): void {
  switch (value.kind) {
    case "array": {
      for (const item of value.items) {
        findReferencesInValue(definition, item, references);
      }
      break;
    }
    case "object": {
      if (!value.record) {
        break;
      }
      if (value.record.recordType === "struct") {
        // Check field name keys, then recurse into field values.
        for (const entry of Object.values(value.entries)) {
          if (entry.fieldDeclaration?.name === definition) {
            references.push(entry.name);
          }
          findReferencesInValue(definition, entry.value, references);
        }
      } else {
        // An enum. Only the "kind" token is a navigable reference — mirrors
        // findDefinition's behavior of returning null when the position is
        // not within the kind token.
        const kindEntry = value.entries["kind"];
        if (kindEntry && kindEntry.value.kind === "literal") {
          const variantName = unquoteAndUnescape(kindEntry.value.token.text);
          const variantDeclaration =
            value.record.nameToDeclaration[variantName];
          if (
            variantDeclaration?.kind === "field" &&
            variantDeclaration.name === definition
          ) {
            references.push(kindEntry.value.token);
          }
        }
      }
      break;
    }
    case "literal": {
      break;
    }
  }
}
