import * as path from "path";
import type { Module, SkirError, Token } from "skir-internal";
import {
  checkCompatibility,
  getTokenForBreakingChange,
} from "skir/dist/compatibility_checker.js";
import { provideCompletionItems as skirProvideCompletionItems } from "skir/dist/completion_helper.js";
import { SkirConfig } from "skir/dist/config.js";
import { parseSkirConfig, SkirConfigError } from "skir/dist/config_parser.js";
import { findDefinition, findReferences } from "skir/dist/definition_finder.js";
import { getShortMessageForBreakingChange } from "skir/dist/error_renderer.js";
import { formatModule } from "skir/dist/formatter.js";
import { formatImportBlock } from "skir/dist/import_block_formatter.js";
import { ModuleSet } from "skir/dist/module_set.js";
import { type Packages } from "skir/dist/package_types.js";
import { snapshotFileContentToModuleSet } from "skir/dist/snapshotter.js";
import * as vscode from "vscode";

// Formatting provider for Skir files
class SkirFormattingProvider implements vscode.DocumentFormattingEditProvider {
  constructor(private readonly skirLanguageExtension: SkirLanguageExtension) {}

  provideDocumentFormattingEdits(
    document: vscode.TextDocument,
  ): vscode.TextEdit[] {
    const moduleBundle = this.skirLanguageExtension.getModuleBundle(
      document.uri.toString(),
    );
    if (!moduleBundle) {
      console.warn(
        `No module bundle found for ${document.uri.toString()}, skipping formatting.`,
      );
      return [];
    }
    const modulePath = moduleBundle?.moduleWorkspace?.modulePath;
    if (!modulePath) {
      console.warn(
        `No workspace found for ${document.uri.toString()}, skipping formatting.`,
      );
      return [];
    }
    const unformattedCode = document.getText();
    const textEdits = formatModule({
      sourceCode: unformattedCode,
      modulePath: modulePath,
    }).textEdits;
    return textEdits.map((edit) =>
      vscode.TextEdit.replace(
        new vscode.Range(
          document.positionAt(edit.oldStart),
          document.positionAt(edit.oldEnd),
        ),
        edit.newText,
      ),
    );
  }

  dispose(): void {}
}

export class SkirLanguageExtension {
  private readonly diagnosticCollection: vscode.DiagnosticCollection;

  constructor() {
    this.diagnosticCollection =
      vscode.languages.createDiagnosticCollection("skir");
  }

  setFileContent(uri: string, content: FileContent | undefined): void {
    const fileType = getFileType(uri);
    if (fileType && !content) {
      this.diagnosticCollection.delete(vscode.Uri.parse(uri));
    }
    switch (fileType) {
      case "skir.yml": {
        if (content) {
          const skirConfigResult = parseSkirConfig(content.content);
          if (skirConfigResult.errors.length <= 0) {
            // The skir config is valid
            const skirConfig: SkirConfigBundle = {
              config: skirConfigResult.skirConfig!,
              yamlContent: content,
            };
            const oldWorkspace = this.workspaces.get(uri);
            if (oldWorkspace) {
              oldWorkspace.skirConfig = skirConfig;
              // The status of whether dependencies are in sync may have changed
              this.setDependencies(oldWorkspace, oldWorkspace.dependencies);
            } else {
              // Create a new workspace and reassign modules
              const workspace = new Workspace(
                uri.replace(/skir\.yml$/, ""),
                skirConfig,
                this.diagnosticCollection,
              );
              this.workspaces.set(uri, workspace);
              this.reassignModulesToWorkspaces();
            }
          } else {
            // The skir config is not valid
            const diagnostics = configErrorsToDiagnostics(
              skirConfigResult.errors,
            );
            this.diagnosticCollection.set(vscode.Uri.parse(uri), diagnostics);
          }
        } else {
          // Delete the workspace
          if (this.workspaces.delete(uri)) {
            this.reassignModulesToWorkspaces();
          }
        }
        break;
      }
      case "*.skir": {
        // Cancel the `scheduledSetFileContent` if it exists
        const timeout = this.uriToTimeout.get(uri);
        if (timeout) {
          clearTimeout(timeout);
          this.uriToTimeout.delete(uri);
        }
        const moduleBundle = this.moduleBundles.get(uri);
        if (moduleBundle) {
          // Remove the module from its workspace
          Workspace.removeModule(moduleBundle);
          // Remove the module bundle from the map
          this.moduleBundles.delete(uri);
        }
        if (content) {
          const moduleBundle = this.makeModuleBundle(content, uri);
          const moduleWorkspace = this.findModuleWorkspace(moduleBundle);
          this.moduleBundles.set(uri, moduleBundle);
          if (moduleWorkspace) {
            Workspace.addModule(moduleBundle, moduleWorkspace);
          }
        }
        break;
      }
      case "skir-snapshot.json": {
        const workspaceUri = uri.replace(/\/skir-snapshot\.json$/, "/skir.yml");
        const workspace = this.workspaces.get(workspaceUri);
        if (workspace) {
          workspace.setLastSnapshot(undefined);
        }
        if (content) {
          // Find the workspace for this snapshot
          if (workspace) {
            const moduleSetOrError = snapshotFileContentToModuleSet(
              content.content,
            );
            if (moduleSetOrError instanceof ModuleSet) {
              workspace.setLastSnapshot({
                moduleSet: moduleSetOrError,
                jsonContent: content,
              });
            } else {
              console.error(`Failed to parse snapshot file ${uri}`);
            }
          } else {
            console.error(`No workspace found for snapshot file ${uri}`);
          }
        }
        break;
      }
      case "dependencies.json": {
        const workspaceUri = uri.replace(
          /\/skir-external\/dependencies\.json$/,
          "/skir.yml",
        );
        const workspace = this.workspaces.get(workspaceUri);
        if (workspace) {
          this.setDependencies(workspace, undefined);
        }
        if (content) {
          const workspaceUri = uri.replace(
            /\/skir-external\/dependencies\.json$/,
            "/skir.yml",
          );
          const workspace = this.workspaces.get(workspaceUri);
          if (workspace) {
            let packages: Packages;
            try {
              packages = JSON.parse(content.content) as Packages;
            } catch (error) {
              console.error(`Failed to parse dependencies file ${uri}:`, error);
              break;
            }
            const depModuleMap = new Map<string, string>();
            for (const pkg of Object.values(packages)) {
              for (const [modulePath, content] of Object.entries(pkg.modules)) {
                depModuleMap.set(modulePath, content);
              }
            }
            const depModuleSet = ModuleSet.compile(
              depModuleMap,
              "no-cache",
              "strict",
            );
            this.setDependencies(workspace, {
              moduleSet: depModuleSet,
              jsonContent: content,
              packages: packages,
            });
          } else {
            console.error(`No workspace found for dependencies file ${uri}`);
          }
        }
        break;
      }
      default: {
        const _: null = fileType;
      }
    }
  }

  getFileContent(uri: string): FileContent | undefined {
    const { workspaces, moduleBundles } = this;
    const fileType = getFileType(uri);
    switch (fileType) {
      case "dependencies.json": {
        const workspaceUri = uri.replace(
          /\/skir-external\/dependencies\.json$/,
          "/skir.yml",
        );
        return workspaces.get(workspaceUri)?.dependencies?.jsonContent;
      }
      case "*.skir": {
        return moduleBundles.get(uri)?.content;
      }
      case "skir-snapshot.json": {
        const workspaceUri = uri.replace(/\/skir-snapshot\.json$/, "/skir.yml");
        return workspaces.get(workspaceUri)?.lastSnapshot?.jsonContent;
      }
      case "skir.yml": {
        return workspaces.get(uri)?.skirConfig.yamlContent;
      }
      case null: {
        return undefined;
      }
      default: {
        const _: never = fileType;
      }
    }
  }

  scheduleSetFileContent(uri: string, document: vscode.TextDocument): void {
    const oldTimeout = this.uriToTimeout.get(uri);
    if (oldTimeout) {
      clearTimeout(oldTimeout);
    }
    const delayMilliseconds = 100;
    const timeout = setTimeout(() => {
      this.uriToTimeout.delete(uri);
      try {
        this.setFileContent(uri, {
          content: document.getText(),
          lastModified: Date.now(),
        });
      } catch (error) {
        console.error(`Error setting file content for ${uri}:`, error);
      }
    }, delayMilliseconds);
    this.uriToTimeout.set(uri, timeout);
  }

  findDefinitionAt(
    uri: string,
    position: number,
  ): vscode.LocationLink[] | null {
    console.log(`Finding definition at ${uri}:${position}`);
    const { moduleBundles } = this;
    const moduleBundle = moduleBundles.get(uri);
    if (!moduleBundle) {
      console.log(`Module bundle not found: ${uri}.`);
      return null;
    }
    const { moduleWorkspace } = moduleBundle;
    if (!moduleWorkspace) {
      console.log(`No workspace for ${uri}.`);
      return null;
    }
    const { workspace } = moduleWorkspace;
    workspace.revolveNow();

    const module = moduleWorkspace.astTree;
    if (!module) {
      console.error(`Module not parsed, probably an error: ${uri}.`);
      return null;
    }
    const definitionMatch = findDefinition(module, position);
    if (!definitionMatch) {
      console.log(`Definition not found: ${uri}.`);
      return null;
    }

    // Convert DefinitionMatch to vscode.Location
    const { modulePath, declaration, referenceToken } = definitionMatch;
    const targetUri = workspace.modulePathToUri(modulePath);
    let targetRange: vscode.Range;
    if (declaration) {
      const targetModule = moduleBundles.get(targetUri);
      if (!targetModule) {
        console.warn(
          `Module ${targetUri} not found, skipping definition lookup.`,
        );
        return null;
      }
      const { positionTracker } = targetModule;
      targetRange = getRangeForToken(declaration.name, positionTracker);
    } else {
      // The user clicked on a module path.
      // Move the cursor to the first line of the module.
      targetRange = new vscode.Range(
        new vscode.Position(0, 0),
        new vscode.Position(0, 0),
      );
    }
    return [
      {
        targetUri: vscode.Uri.parse(targetUri),
        targetRange: targetRange,
        originSelectionRange: getRangeForToken(
          referenceToken,
          moduleBundle.positionTracker,
        ),
      },
    ];
  }

  /** Get module bundle for a given URI (used by DocumentLinkProvider) */
  getModuleBundle(uri: string): ModuleBundle | undefined {
    return this.moduleBundles.get(uri);
  }

  /**
   * Finds all import update text edits needed after a .skir file is
   * renamed/moved from oldUri to newUri.
   * Returns a map from file URI → TextEdit[].
   */
  buildImportUpdateEdits(
    oldUri: string,
    newUri: string,
  ): Map<string, vscode.TextEdit[]> {
    const result = new Map<string, vscode.TextEdit[]>();

    // Find the workspace that contains the old file.
    const workspace =
      this.moduleBundles.get(oldUri)?.moduleWorkspace?.workspace;

    if (!workspace) return result;

    let oldModulePath: string;
    let newModulePath: string;
    try {
      oldModulePath = workspace.moduleUriToPath(oldUri);
      newModulePath = workspace.moduleUriToPath(newUri);
    } catch (e) {
      console.error(e);
      return result;
    }
    if (oldModulePath === newModulePath) return result;

    workspace.revolveNow();

    return workspace.makeImportEditsForModulePathChange(
      oldUri,
      oldModulePath,
      newModulePath,
    );
  }

  private setDependencies(
    workspace: Workspace,
    dependencies: Dependencies | undefined,
  ): void {
    const { oldModules, newModules } = workspace.setDependencies(dependencies);
    for (const oldModule of oldModules) {
      this.moduleBundles.delete(oldModule.uri);
    }
    for (const newModule of newModules) {
      this.moduleBundles.set(newModule.uri, newModule);
    }
  }

  private reassignModulesToWorkspaces(): void {
    if (this.reassigneModulesTimeout) {
      // Already scheduled, do nothing.
      return;
    }
    this.reassigneModulesTimeout = setTimeout(() => {
      console.log("Reassigning modules to workspaces...");
      for (const moduleBundle of this.moduleBundles.values()) {
        if (moduleBundle.isExternalDependency) {
          continue;
        }
        Workspace.removeModule(moduleBundle);
        const newWorkspace = this.findModuleWorkspace(moduleBundle);
        if (newWorkspace) {
          Workspace.addModule(moduleBundle, newWorkspace);
        }
      }
      for (const workspace of this.workspaces.values()) {
        workspace.scheduleResolution();
      }
      this.reassigneModulesTimeout = undefined;
    });
  }

  private makeModuleBundle(content: FileContent, uri: string): ModuleBundle {
    const positionTracker = new PositionTracker(content.content);
    const isExternalDependency = false;
    return { uri, isExternalDependency, content, positionTracker };
  }

  /** Finds the workspace which contains the given module URI. */
  private findModuleWorkspace(
    moduleBundle: ModuleBundle,
  ): ModuleWorkspace | undefined {
    let match: Workspace | undefined;
    const leftIsBetter = (
      left: Workspace,
      right: Workspace | undefined,
    ): boolean => {
      if (right === undefined || left.srcUri.length < right.srcUri.length) {
        return true;
      }
      if (left.srcUri.length === right.srcUri.length) {
        // Completely arbitrary, just to have a consistent order.
        return left.srcUri < right.srcUri;
      }
      return false;
    };
    const moduleUri = moduleBundle.uri;
    for (const workspace of this.workspaces.values()) {
      const { rootUri } = workspace;
      if (moduleUri.startsWith(rootUri) && leftIsBetter(workspace, match)) {
        match = workspace;
      }
    }
    if (match) {
      const { srcUri, externalUri } = match;
      if (moduleUri.startsWith(srcUri) || moduleUri.startsWith(externalUri)) {
        return {
          workspace: match,
          modulePath: match.moduleUriToPath(moduleUri),
        };
      }
    }
    // Raise a warning and possible lexical/parsing errors.
    const warningMessage = match
      ? "Not in skir-src directory"
      : "No skir workspace found; add a skir.yml file";
    const warning = new vscode.Diagnostic(
      new vscode.Range(new vscode.Position(0, 0), new vscode.Position(0, 0)),
      warningMessage,
      vscode.DiagnosticSeverity.Warning,
    );
    this.diagnosticCollection.set(vscode.Uri.parse(moduleUri), [warning]);
    return undefined;
  }

  /** Removes all the files which seem to no longer exist on the filesystem. */
  async runGarbageCollection(): Promise<void> {
    const uris = Array.from(this.moduleBundles.keys());
    for (const workspace of this.workspaces.values()) {
      uris.push(workspace.skirYmlUri);
      if (workspace.lastSnapshot) {
        uris.push(workspace.rootUri + "skir-snapshot.json");
      }
      if (workspace.dependencies) {
        uris.push(workspace.rootUri + "skir-external/dependencies.json");
      }
    }
    for (const uri of uris) {
      let isFile = false;
      try {
        const stat = await vscode.workspace.fs
          .stat(vscode.Uri.parse(uri))
          .then();
        isFile = stat.type === vscode.FileType.File;
      } catch (_error) {
        // Do nothing, the file does not exist.
      }
      if (!isFile) {
        console.log(`File no longer exists, removing: ${uri}`);
        this.setFileContent(uri, undefined);
      }
    }
  }

  /** Returns hover documentation for the symbol at the given offset, if any. */
  getHoverInfo(uri: string, offset: number): vscode.Hover | null {
    const moduleBundle = this.moduleBundles.get(uri);
    if (!moduleBundle) return null;
    const module = moduleBundle.moduleWorkspace?.astTree;
    if (!module) return null;

    const definitionMatch = findDefinition(module, offset);
    if (!definitionMatch) return null;
    const { declaration } = definitionMatch;
    if (!declaration) return null;
    // Only record, method, constant and field declarations carry documentation
    if (
      declaration.kind !== "record" &&
      declaration.kind !== "method" &&
      declaration.kind !== "constant" &&
      declaration.kind !== "field"
    ) {
      return null;
    }
    const docText = declaration.doc.text.trim();
    if (!docText) return null;
    const md = new vscode.MarkdownString();
    md.appendText(docText);
    return new vscode.Hover(md);
  }

  /** Returns all locations that reference the symbol at the given offset. */
  findAllReferences(uri: string, offset: number): vscode.Location[] {
    const result = this.getDefinitionToken(uri, offset);
    if (!result) return [];
    const { definitionToken, workspace } = result;
    workspace.revolveNow();
    const resolvedModules = workspace.getResolvedModules();
    const referenceTokens = findReferences(definitionToken, resolvedModules);
    return referenceTokens
      .map((token) => this.tokenToLocation(token, workspace))
      .filter((loc): loc is vscode.Location => loc !== null);
  }

  /** Returns completion items for the given position in a skir file. */
  getCompletionItems(
    uri: string,
    offset: number,
    document: vscode.TextDocument,
  ): vscode.CompletionItem[] {
    const moduleBundle = this.moduleBundles.get(uri);
    if (!moduleBundle) return [];
    const { moduleWorkspace } = moduleBundle;
    if (!moduleWorkspace) return [];
    const { workspace, modulePath } = moduleWorkspace;
    const oldModuleSet = workspace.getLastResolvedModuleSet();
    if (!oldModuleSet) return [];
    const moduleContent = document.getText();
    const result = skirProvideCompletionItems(
      modulePath,
      moduleContent,
      offset,
      oldModuleSet,
    );
    if (!result) return [];
    const placeholderRange = new vscode.Range(
      document.positionAt(result.placeholderStartPos),
      document.positionAt(result.placeholderEndPos),
    );
    return result.items.map((item) => {
      const completionItem = new vscode.CompletionItem(item.name);
      completionItem.range = placeholderRange;
      if (item.doc?.text) {
        const md = new vscode.MarkdownString();
        md.appendText(item.doc.text.trim());
        completionItem.documentation = md;
      }
      if (item.modulePath) {
        completionItem.detail = `Auto-import from "${modulePath}"`;
      }
      if (item.insertText) {
        completionItem.insertText = item.insertText;
      }
      const { importBlockEdit } = item;
      if (importBlockEdit) {
        completionItem.additionalTextEdits = [
          vscode.TextEdit.replace(
            new vscode.Range(
              document.positionAt(importBlockEdit.oldStart),
              document.positionAt(importBlockEdit.oldEnd),
            ),
            importBlockEdit.newText,
          ),
        ];
      }
      return completionItem;
    });
  }

  /**
   * Validates that a rename is allowed and returns the word range + placeholder.
   * Throws if rename is not permitted (e.g., external symbol).
   */
  prepareRenameAt(
    uri: string,
    offset: number,
    document: vscode.TextDocument,
    position: vscode.Position,
  ): { range: vscode.Range; placeholder: string } {
    const moduleBundle = this.moduleBundles.get(uri);
    if (!moduleBundle) throw new Error("Cannot rename: module not found");
    const { moduleWorkspace } = moduleBundle;
    if (!moduleWorkspace) throw new Error("No workspace");
    moduleWorkspace.workspace.revolveNow();
    const module = moduleBundle.moduleWorkspace?.astTree;
    if (!module) throw new Error("No AST tree");

    // If the cursor is on a reference to an external symbol, reject rename
    const definitionMatch = findDefinition(module, offset);
    if (definitionMatch !== null) {
      // declaration === undefined means the cursor is on a module path in an
      // import statement, which is not a renameable symbol.
      if (definitionMatch.declaration === undefined) {
        throw new Error("Cannot rename: no renameable symbol at cursor");
      }
      if (definitionMatch.modulePath.startsWith("@")) {
        throw new Error(
          "Cannot rename: symbol is defined in an external dependency",
        );
      }
    }

    const wordRange = document.getWordRangeAtPosition(
      position,
      /[a-zA-Z_][a-zA-Z0-9_]*/,
    );
    if (!wordRange) throw new Error("Cannot rename: no symbol at cursor");
    return { range: wordRange, placeholder: document.getText(wordRange) };
  }

  /**
   * Builds a WorkspaceEdit that renames every occurrence of the symbol at
   * the given offset to `newName`.
   */
  provideRenameEditsAt(
    uri: string,
    offset: number,
    newName: string,
  ): vscode.WorkspaceEdit | null {
    const result = this.getDefinitionToken(uri, offset);
    if (!result) return null;
    const { definitionToken, workspace } = result;

    // Reject renaming of external symbols
    if (definitionToken.line.modulePath.startsWith("@")) return null;

    workspace.revolveNow();
    const resolvedModules = workspace.getResolvedModules();
    const referenceTokens = findReferences(definitionToken, resolvedModules);

    // Rename the definition itself plus every reference
    const allTokens = [definitionToken, ...referenceTokens];
    const workspaceEdit = new vscode.WorkspaceEdit();
    for (const token of allTokens) {
      const location = this.tokenToLocation(token, workspace);
      if (!location) continue;
      workspaceEdit.replace(
        location.uri,
        location.range,
        getTokenReplacement(token, newName),
      );
    }
    return workspaceEdit;
  }

  /**
   * Resolves the name token of the declaration that the cursor is pointing at.
   * If the cursor is on a reference, the definition's name token is returned.
   * If the cursor is on the declaration name itself, that token is returned.
   */
  private getDefinitionToken(
    uri: string,
    offset: number,
  ): { definitionToken: Token; workspace: Workspace } | null {
    const moduleBundle = this.moduleBundles.get(uri);
    if (!moduleBundle) return null;
    const module = moduleBundle.moduleWorkspace?.astTree;
    if (!module) return null;
    const { moduleWorkspace } = moduleBundle;
    if (!moduleWorkspace) return null;
    const { workspace } = moduleWorkspace;

    const definitionMatch = findDefinition(module, offset);
    if (definitionMatch) {
      const { declaration } = definitionMatch;
      if (!declaration) return null; // module-path match, no name token
      return { definitionToken: declaration.name, workspace };
    } else {
      // Cursor is on the definition itself
      const token = findDeclarationNameAtPosition(module, offset);
      if (!token) return null;
      return { definitionToken: token, workspace };
    }
  }

  /**
   * Converts a Token (from any module in the workspace) to a vscode.Location.
   */
  private tokenToLocation(
    token: Token,
    workspace: Workspace,
  ): vscode.Location | null {
    const { modulePath } = token.line;
    const moduleUri = workspace.modulePathToUri(modulePath);
    const moduleBundle = this.moduleBundles.get(moduleUri);
    if (!moduleBundle) {
      console.warn(`Module bundle not found for token in: ${modulePath}`);
      return null;
    }
    const { positionTracker } = moduleBundle;
    return new vscode.Location(
      vscode.Uri.parse(moduleUri),
      getRangeForToken(token, positionTracker),
    );
  }

  private reassigneModulesTimeout?: NodeJS.Timeout;
  private readonly moduleBundles = new Map<string, ModuleBundle>(); // key: file URI
  private readonly workspaces = new Map<string, Workspace>(); // key: skir.yml file URI
  private readonly uriToTimeout = new Map<string, NodeJS.Timeout>();
}

function getFileType(
  uri: string,
): "skir.yml" | "skir-snapshot.json" | "*.skir" | "dependencies.json" | null {
  if (uri.endsWith("/skir-external/dependencies.json")) {
    return "dependencies.json";
  } else if (/\/skir-external\//.test(uri)) {
    return null;
  } else if (uri.endsWith("/skir.yml")) {
    return "skir.yml";
  } else if (uri.endsWith("/skir-snapshot.json")) {
    return "skir-snapshot.json";
  } else if (uri.endsWith(".skir")) {
    return "*.skir";
  } else {
    return null;
  }
}

interface ModuleWorkspace {
  readonly workspace: Workspace;
  readonly modulePath: string;
  astTree?: Module;
}

interface FileContent {
  content: string;
  /** Mtime */
  lastModified: number;
}

interface ModuleBundle {
  readonly uri: string;
  readonly isExternalDependency: boolean;
  readonly content: FileContent;
  readonly positionTracker: PositionTracker;
  moduleWorkspace?: ModuleWorkspace;
}

interface Dependencies {
  readonly moduleSet: ModuleSet;
  readonly jsonContent: FileContent;
  readonly packages: Packages;
}

interface Snapshot {
  readonly moduleSet: ModuleSet;
  readonly jsonContent: FileContent;
}

interface SkirConfigBundle {
  readonly config: SkirConfig;
  yamlContent: FileContent;
}

class Workspace {
  constructor(
    readonly rootUri: string,
    public skirConfig: SkirConfigBundle,
    private diagnosticCollection: vscode.DiagnosticCollection,
  ) {}

  readonly srcUri = this.rootUri + "skir-src/";
  readonly externalUri = this.rootUri + "skir-external/";
  readonly skirYmlUri = this.rootUri + "skir.yml";
  // key: module path; does not include dependency modules
  private readonly modules = new Map<string, ModuleBundle>();
  private scheduledResolution?: Readonly<{
    timeout: NodeJS.Timeout;
    promise: Promise<void>;
    callback: () => void;
  }>;
  private lastSnapshotData?: Snapshot;
  private dependenciesData?: Dependencies;
  // key: module path
  private readonly dependencyModules = new Map<string, ModuleBundle>();
  private lastResolvedModuleSet: ModuleSet | undefined = undefined;
  private changedSinceLastResolution = false;

  static addModule(
    moduleBundle: ModuleBundle,
    moduleWorkspace: ModuleWorkspace,
  ): void {
    // If the module was already in a workspace, remove it from the old workspace.
    Workspace.removeModule(moduleBundle);
    const { workspace } = moduleWorkspace;
    moduleBundle.moduleWorkspace = moduleWorkspace;
    workspace.modules.set(moduleWorkspace.modulePath, moduleBundle);
    workspace.scheduleResolution();
    workspace.changedSinceLastResolution = true;
  }

  static removeModule(moduleBundle: ModuleBundle): void {
    const { moduleWorkspace } = moduleBundle;
    if (!moduleWorkspace) {
      return;
    }
    const { workspace } = moduleWorkspace;
    workspace.modules.delete(moduleWorkspace.modulePath);
    moduleBundle.moduleWorkspace = undefined;
    workspace.scheduleResolution();
    workspace.changedSinceLastResolution = true;
  }

  get dependencies(): Dependencies | undefined {
    return this.dependenciesData;
  }

  setDependencies(dependencies: Dependencies | undefined): {
    readonly oldModules: readonly ModuleBundle[];
    readonly newModules: readonly ModuleBundle[];
  } {
    const oldDependencies = this.dependencies;
    if (oldDependencies) {
      // Remove old diagnostics
      const moduleUris = new Set<string>();
      for (const error of oldDependencies.moduleSet.errors) {
        const { moduleUri } = this.getModuleForToken(error.token);
        moduleUris.add(moduleUri);
      }
      for (const moduleUri of moduleUris) {
        this.diagnosticCollection.delete(vscode.Uri.parse(moduleUri));
      }
    }
    const oldModules = [...this.dependencyModules.values()];
    this.dependencyModules.clear();
    this.dependenciesData = dependencies;
    const newModules: ModuleBundle[] = [];
    let dependenciesInSync: boolean;
    if (dependencies) {
      const modulePathToErrors = new Map<string, MutableErrorsAndWarnings>();
      for (const errorsOrWarnings of ERRORS_WARNINGS) {
        for (const error of dependencies.moduleSet[errorsOrWarnings]) {
          if (error.errorIsInOtherModule) {
            continue;
          }
          const { modulePath } = this.getModuleForToken(error.token);
          let moduleErrors = modulePathToErrors.get(modulePath);
          if (!moduleErrors) {
            moduleErrors = { errors: [], warnings: [] };
            modulePathToErrors.set(modulePath, moduleErrors);
          }
          moduleErrors[errorsOrWarnings].push(error);
        }
      }
      for (const [
        modulePath,
        module,
      ] of dependencies.moduleSet.modules.entries()) {
        const moduleUri = this.modulePathToUri(modulePath);
        const content = module.result?.sourceCode ?? "";
        const positionTracker = new PositionTracker(content);
        const moduleBundle: ModuleBundle = {
          uri: moduleUri,
          isExternalDependency: true,
          content: {
            content: content,
            lastModified: 0,
          },
          positionTracker: positionTracker,
          moduleWorkspace: {
            workspace: this,
            modulePath,
          },
        };
        this.dependencyModules.set(modulePath, moduleBundle);
        newModules.push(moduleBundle);
        const errors = modulePathToErrors.get(modulePath) ?? {
          errors: [],
          warnings: [],
        };
        const diagnostics = errorsToDiagnostics(errors, moduleBundle);
        this.diagnosticCollection.set(vscode.Uri.parse(moduleUri), diagnostics);
      }
      // Verify that the dependencies are in sync with the skir config
      dependenciesInSync = Object.entries(
        this.skirConfig.config.dependencies,
      ).every(
        ([packageId, version]) =>
          dependencies.packages[packageId]?.version === version,
      );
    } else {
      dependenciesInSync = true;
    }
    this.diagnosticCollection.set(
      vscode.Uri.parse(this.skirYmlUri),
      dependenciesInSync
        ? []
        : [
            new vscode.Diagnostic(
              new vscode.Range(
                new vscode.Position(0, 0),
                new vscode.Position(0, 0),
              ),
              "Dependencies out of sync; run npx skir gen",
              vscode.DiagnosticSeverity.Warning,
            ),
          ],
    );
    this.scheduleResolution();
    this.changedSinceLastResolution = true;
    return { oldModules, newModules };
  }

  get lastSnapshot(): Snapshot | undefined {
    return this.lastSnapshotData;
  }

  setLastSnapshot(snapshot: Snapshot | undefined): void {
    this.lastSnapshotData = snapshot;
    this.changedSinceLastResolution = true;
    this.scheduleResolution();
  }

  scheduleResolution(): void {
    if (this.scheduledResolution) {
      clearTimeout(this.scheduledResolution.timeout);
    }
    const delayMilliseconds = 500;
    const timeout = setTimeout(() => {
      this.resolve();
    }, delayMilliseconds);
    const scheduledResolution = {
      timeout,
      promise: Promise.resolve(),
      callback: (() => {
        throw new Error("callback not set");
      }) as () => void,
    };
    scheduledResolution.promise = new Promise<void>((resolve) => {
      scheduledResolution.callback = resolve;
    });
    this.scheduledResolution = scheduledResolution;
  }

  get resolutionDone(): Promise<void> {
    if (this.scheduledResolution) {
      return this.scheduledResolution.promise;
    }
    return Promise.resolve();
  }

  /** Force a resolution to happen *now*, cancel any scheduled resolution. */
  revolveNow(): void {
    if (this.scheduledResolution) {
      clearTimeout(this.scheduledResolution.timeout);
    }
    this.resolve();
  }

  /**
   * Synchronously performs type resolution (and validation).
   * Stores the errors in every module bundle.
   */
  private resolve(): void {
    const {
      dependenciesData: dependencies,
      lastSnapshotData: lastSnapshot,
      modules,
    } = this;
    try {
      if (!this.changedSinceLastResolution) return;
      // Create the map from module path to module content.
      const moduleMap = new Map<string, string>();
      for (const [modulePath, moduleBundle] of modules.entries()) {
        if (!modulePath.startsWith("@")) {
          moduleMap.set(modulePath, moduleBundle.content.content);
        }
      }
      if (dependencies) {
        for (const pkg of Object.values(dependencies.packages)) {
          for (const [modulePath, content] of Object.entries(pkg.modules)) {
            moduleMap.set(modulePath, content);
          }
        }
      }
      const moduleSet = ModuleSet.compile(
        moduleMap,
        this.lastResolvedModuleSet ?? "no-cache",
        "lenient",
      );
      let anyError = false;
      for (const [modulePath, parsedModule] of moduleSet.modules) {
        const moduleBundle = (modules.get(modulePath) ??
          this.dependencyModules.get(modulePath))!;
        const errors = parsedModule.errors.filter(
          (e) => !e.errorIsInOtherModule,
        );
        const warnings = parsedModule.warnings ?? [];
        anyError = anyError || errors.length > 0;
        const { moduleWorkspace } = moduleBundle;
        if (moduleWorkspace?.workspace !== this) {
          throw new Error(`Module workspace mismatch for ${moduleBundle.uri}`);
        }
        moduleWorkspace.astTree = parsedModule.result;
        this.updateDiagnostics(moduleBundle, { errors, warnings });
      }
      this.lastResolvedModuleSet = moduleSet;
      if (anyError || !lastSnapshot) {
        return;
      }
      // Look for breaking changes since the last snapshot.
      const breakingChanges = checkCompatibility({
        before: lastSnapshot.moduleSet,
        after: moduleSet,
      });
      const moduleUriToDiagnostics = new Map<string, vscode.Diagnostic[]>();
      for (const breakingChange of breakingChanges) {
        const token = getTokenForBreakingChange(breakingChange);
        if (!token) {
          // Some breaking change errors can't be tied to a specific token in
          // the new snapshot. We skip them.
          continue;
        }
        const { modulePath, moduleUri } = this.getModuleForToken(token);
        const module = this.getModule(modulePath);
        if (!module) {
          // Should not happen.
          console.error(`Module not found: ${moduleUri}`);
          continue;
        }
        const { positionTracker } = module!;
        const range = getRangeForToken(token, positionTracker);
        const message =
          "Breaking change: " +
          getShortMessageForBreakingChange(
            breakingChange,
            lastSnapshot.moduleSet,
          );

        const diagnostics = moduleUriToDiagnostics.get(moduleUri) || [];
        if (diagnostics.length <= 0) {
          moduleUriToDiagnostics.set(moduleUri, diagnostics);
        }
        diagnostics.push(
          new vscode.Diagnostic(
            range,
            message,
            vscode.DiagnosticSeverity.Warning,
          ),
        );
      }
      for (const [moduleUri, diagnostics] of moduleUriToDiagnostics.entries()) {
        const uri = vscode.Uri.parse(moduleUri);
        this.diagnosticCollection.set(uri, diagnostics);
      }
    } catch (error) {
      console.error("Error during resolution:", error);
    } finally {
      this.scheduledResolution?.callback();
      this.scheduledResolution = undefined;
      this.changedSinceLastResolution = false;
    }
  }

  private updateDiagnostics(
    moduleBundle: ModuleBundle,
    errors: ErrorsAndWarnings,
  ): void {
    const { uri } = moduleBundle;
    const diagnostics = errorsToDiagnostics(errors, moduleBundle);
    this.diagnosticCollection.set(vscode.Uri.parse(uri), diagnostics);
  }

  private getModule(modulePath: string): ModuleBundle | undefined {
    return (
      this.modules.get(modulePath) ?? this.dependencyModules.get(modulePath)
    );
  }

  private getModuleForToken(token: Token): {
    readonly modulePath: string;
    readonly moduleUri: string;
  } {
    const { modulePath } = token.line;
    return {
      modulePath: modulePath,
      moduleUri: this.modulePathToUri(modulePath),
    };
  }

  moduleUriToPath(uri: string): string {
    if (uri.startsWith(this.srcUri)) {
      return uri
        .substring(this.srcUri.length)
        .split("/")
        .map(decodeURIComponent)
        .join("/");
    } else if (uri.startsWith(this.externalUri)) {
      return uri
        .substring(this.externalUri.length)
        .replace(/\.readonly.skir$/, ".skir")
        .split("/")
        .map(decodeURIComponent)
        .join("/");
    } else {
      throw new Error(`Invalid module URI: ${uri}`);
    }
  }

  modulePathToUri(modulePath: string): string {
    if (modulePath.startsWith(this.rootUri)) {
      // Already a URI
      return modulePath;
    } else if (modulePath.startsWith("@")) {
      return (
        this.externalUri +
        modulePath
          .replace(/\.skir$/, ".readonly.skir")
          .split("/")
          .map(encodeURIComponent)
          .join("/")
      );
    } else {
      return (
        this.srcUri + modulePath.split("/").map(encodeURIComponent).join("/")
      );
    }
  }

  /** Returns all successfully resolved modules in this workspace. */
  getResolvedModules(): readonly Module[] {
    const { lastResolvedModuleSet } = this;
    return lastResolvedModuleSet
      ? [...lastResolvedModuleSet.modules.values()].map((it) => it.result)
      : [];
  }

  getLastResolvedModuleSet(): ModuleSet | undefined {
    return this.lastResolvedModuleSet;
  }

  /**
   * Scans every module in this workspace for imports of oldModulePath and
   * returns text edits that replace those import path strings with
   * newModulePath.
   * The map is keyed by file URI; the renamed file itself (oldUri) is skipped.
   */
  makeImportEditsForModulePathChange(
    oldUri: string,
    oldModulePath: string,
    newModulePath: string,
  ): Map<string, vscode.TextEdit[]> {
    const result = new Map<string, vscode.TextEdit[]>();
    for (const moduleBundle of this.modules.values()) {
      if (moduleBundle.uri === oldUri) continue; // Skip the renamed file itself.
      const module = moduleBundle.moduleWorkspace?.astTree;
      if (!module) continue;

      // Skip modules that don't import the renamed file.
      if (!(oldModulePath in module.pathToImportedNames)) continue;

      // Build a new pathToImportedNames with the key renamed.
      const newPathToImportedNames = { ...module.pathToImportedNames };
      newPathToImportedNames[newModulePath] =
        newPathToImportedNames[oldModulePath];
      delete newPathToImportedNames[oldModulePath];

      // Re-format the entire import block (mirrors completion_helper.ts).
      const newImportBlock = formatImportBlock(newPathToImportedNames);
      const { importBlockRange } = module;
      const { positionTracker } = moduleBundle;

      const startPos = positionTracker.getPosition(importBlockRange!.start);
      const endPos = positionTracker.getPosition(importBlockRange!.end);
      const edit = vscode.TextEdit.replace(
        new vscode.Range(
          new vscode.Position(startPos.line, startPos.column),
          new vscode.Position(endPos.line, endPos.column),
        ),
        newImportBlock,
      );

      result.set(moduleBundle.uri, [edit]);
    }
    return result;
  }
}

class SkirCompletionProvider implements vscode.CompletionItemProvider {
  constructor(private readonly skirLanguageExtension: SkirLanguageExtension) {}

  provideCompletionItems(
    document: vscode.TextDocument,
    position: vscode.Position,
    _token: vscode.CancellationToken,
    _context: vscode.CompletionContext,
  ): vscode.CompletionItem[] {
    try {
      const uri = document.uri.toString();
      const offset = document.offsetAt(position);
      return this.skirLanguageExtension.getCompletionItems(
        uri,
        offset,
        document,
      );
    } catch (error) {
      console.error("Error providing completions:", error);
      return [];
    }
  }
}

const skirLanguageExtension = new SkirLanguageExtension();

class SkirDefinitionProvider implements vscode.DefinitionProvider {
  constructor(private readonly skirLanguageExtension: SkirLanguageExtension) {}

  provideDefinition(
    document: vscode.TextDocument,
    position: vscode.Position,
  ): vscode.LocationLink[] | null {
    try {
      const offset = document.offsetAt(position);
      const uri = document.uri.toString();
      return this.skirLanguageExtension.findDefinitionAt(uri, offset);
    } catch (error) {
      console.error(`Error finding definition at ${position}:`, error);
      throw error;
    }
  }
}

class SkirHoverProvider implements vscode.HoverProvider {
  constructor(private readonly skirLanguageExtension: SkirLanguageExtension) {}

  provideHover(
    document: vscode.TextDocument,
    position: vscode.Position,
  ): vscode.Hover | null {
    try {
      const uri = document.uri.toString();
      const offset = document.offsetAt(position);
      return this.skirLanguageExtension.getHoverInfo(uri, offset);
    } catch (error) {
      console.error("Error providing hover:", error);
      return null;
    }
  }
}

class SkirReferenceProvider implements vscode.ReferenceProvider {
  constructor(private readonly skirLanguageExtension: SkirLanguageExtension) {}

  provideReferences(
    document: vscode.TextDocument,
    position: vscode.Position,
    _context: vscode.ReferenceContext,
  ): vscode.Location[] {
    try {
      const uri = document.uri.toString();
      const offset = document.offsetAt(position);
      return this.skirLanguageExtension.findAllReferences(uri, offset);
    } catch (error) {
      console.error("Error providing references:", error);
      return [];
    }
  }
}

class SkirRenameProvider implements vscode.RenameProvider {
  constructor(private readonly skirLanguageExtension: SkirLanguageExtension) {}

  prepareRename(
    document: vscode.TextDocument,
    position: vscode.Position,
  ): { range: vscode.Range; placeholder: string } {
    const uri = document.uri.toString();
    const offset = document.offsetAt(position);
    // Throws if rename is not permitted
    return this.skirLanguageExtension.prepareRenameAt(
      uri,
      offset,
      document,
      position,
    );
  }

  provideRenameEdits(
    document: vscode.TextDocument,
    position: vscode.Position,
    newName: string,
  ): vscode.WorkspaceEdit | null {
    try {
      const uri = document.uri.toString();
      const offset = document.offsetAt(position);
      return this.skirLanguageExtension.provideRenameEditsAt(
        uri,
        offset,
        newName,
      );
    } catch (error) {
      console.error("Error providing rename edits:", error);
      return null;
    }
  }
}

class FileContentManager {
  private readonly documentChangeListener: vscode.Disposable;
  private disposed = false;

  constructor(private readonly skirLanguageExtension: SkirLanguageExtension) {
    // Listen for document changes (unsaved edits)
    this.documentChangeListener = vscode.workspace.onDidChangeTextDocument(
      (event) => {
        const uri = event.document.uri;
        const uriString = uri.toString();

        // Only supported file types
        if (getFileType(uriString)) {
          this.skirLanguageExtension.scheduleSetFileContent(
            uriString,
            event.document,
          );
        }
      },
    );

    this.scheduleScanLoop();
  }

  async runScan(): Promise<void> {
    const workspaceFolders = vscode.workspace.workspaceFolders;
    if (!workspaceFolders) {
      return;
    }

    for (const folder of workspaceFolders) {
      const files = (
        await vscode.workspace.findFiles(
          new vscode.RelativePattern(
            folder,
            "**/{skir.yml,*.skir,skir-snapshot.json}",
          ),
        )
      ).concat(
        await vscode.workspace.findFiles(
          new vscode.RelativePattern(
            folder,
            "**/skir-external/dependencies.json",
          ),
        ),
      );
      // Make sure skir.yml files are processed first
      const uriToTier = (uri: string): number => {
        if (uri.endsWith("/skir.yml")) {
          return 1;
        } else if (uri.endsWith("/dependencies.json")) {
          return 2;
        } else {
          return 3;
        }
      };
      files.sort((a, b) => uriToTier(a.toString()) - uriToTier(b.toString()));
      for (const uri of files) {
        const uriString = uri.toString();
        const oldContent = this.skirLanguageExtension.getFileContent(uriString);
        let mtime: number | undefined;
        try {
          const stat = await vscode.workspace.fs.stat(uri);
          mtime = stat.mtime;
        } catch (error) {
          console.error(`Failed to stat file ${uri}:`, error);
          continue;
        }
        if (
          oldContent &&
          oldContent.lastModified &&
          oldContent.lastModified >= mtime
        ) {
          // No need to read the file again, it hasn't changed.
          continue;
        }
        let content: string;
        try {
          const text = await vscode.workspace.fs.readFile(uri);
          content = Buffer.from(text).toString("utf-8");
        } catch (error) {
          console.error(`Failed to read file ${uri}:`, error);
          continue;
        }
        if (oldContent && oldContent.content === content) {
          // No need to update, content is the same.
          continue;
        }
        this.skirLanguageExtension.setFileContent(uriString, {
          content,
          lastModified: mtime,
        });
      }
    }
  }

  /**
   * Starts a loop that periodically runs garbage collection on all files stored
   * in `skirLanguageExtension` and then runs a scan on the filesystem.
   */
  scheduleScanLoop(): void {
    const delayMilliseconds = 5000; // 5 seconds
    setTimeout(() => this.runScanLoopIteration(), delayMilliseconds);
  }

  private async runScanLoopIteration(): Promise<void> {
    if (this.disposed) {
      return;
    }
    try {
      await this.skirLanguageExtension.runGarbageCollection();
      await this.runScan();
    } catch (error) {
      console.error("Error during scheduled scan:", error);
    }
    this.scheduleScanLoop(); // Reschedule the next scan
  }

  dispose(): void {
    this.documentChangeListener.dispose();
    this.disposed = true;
  }
}

/** Gets the (line number, column number) for a given offset. */
class PositionTracker {
  private readonly lineBreaks: number[];

  constructor(private readonly text: string) {
    this.text = text;
    this.lineBreaks = PositionTracker.findLineBreaks(text);
  }

  private static findLineBreaks(text: string): number[] {
    const breaks: number[] = [0]; // Start of first line
    for (let i = 0; i < text.length; i++) {
      const char = text[i];
      if (char === "\n") {
        breaks.push(i + 1);
      } else if (char === "\r") {
        // Handle \r\n (don't double-count)
        if (i + 1 < text.length && text[i + 1] === "\n") {
          breaks.push(i + 2);
          i++; // Skip the \n
        } else {
          // Standalone \r
          breaks.push(i + 1);
        }
      }
    }
    return breaks;
  }

  getPosition(offset: number): { line: number; column: number } {
    if (offset < 0 || offset > this.text.length) {
      throw new Error(
        `Offset ${offset} is out of bounds (text length: ${this.text.length})`,
      );
    }

    // Binary search to find the line containing this offset
    let left = 0;
    let right = this.lineBreaks.length - 1;
    let lineIndex = 0;

    while (left <= right) {
      const mid = Math.floor((left + right) / 2);

      if (this.lineBreaks[mid] <= offset) {
        lineIndex = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    // If we're beyond the last line break, check if there's a next one
    if (
      lineIndex < this.lineBreaks.length - 1 &&
      offset >= this.lineBreaks[lineIndex + 1]
    ) {
      lineIndex++;
    }

    const lineStart = this.lineBreaks[lineIndex];
    const column = offset - lineStart;

    return { line: lineIndex, column };
  }
}

function errorsToDiagnostics(
  errors: ErrorsAndWarnings,
  moduleBundle: ModuleBundle,
): vscode.Diagnostic[] {
  const { positionTracker } = moduleBundle;
  const errorToDiagnostic = (
    error: SkirError,
    severity: vscode.DiagnosticSeverity,
  ): vscode.Diagnostic =>
    new vscode.Diagnostic(
      getRangeForToken(error.token, positionTracker),
      error.message || `expected: ${error.expected}`,
      severity,
    );
  return errors.errors
    .map((e) => errorToDiagnostic(e, vscode.DiagnosticSeverity.Error))
    .concat(
      errors.warnings.map((e) =>
        errorToDiagnostic(e, vscode.DiagnosticSeverity.Warning),
      ),
    );
}

function configErrorsToDiagnostics(
  errors: readonly SkirConfigError[],
): vscode.Diagnostic[] {
  const zeroRange = new vscode.Range(
    new vscode.Position(0, 0),
    new vscode.Position(0, 0),
  );
  return errors.map(
    (e) =>
      new vscode.Diagnostic(
        e.range
          ? new vscode.Range(
              new vscode.Position(
                e.range.start.lineNumber - 1,
                e.range.start.colNumber - 1,
              ),
              new vscode.Position(
                e.range.end.lineNumber - 1,
                e.range.end.colNumber - 1,
              ),
            )
          : zeroRange,
        e.message,
        vscode.DiagnosticSeverity.Error,
      ),
  );
}

function getRangeForToken(
  token: Token,
  positionTracker: PositionTracker,
): vscode.Range {
  const startPos = positionTracker.getPosition(token.position);
  const endPos = positionTracker.getPosition(
    token.position + token.originalText.length,
  );
  return new vscode.Range(
    new vscode.Position(startPos.line, startPos.column),
    new vscode.Position(endPos.line, endPos.column),
  );
}

/**
 * Returns the replacement text for a token during a rename operation.
 * If the token text is wrapped in single or double quotes the new name is
 * wrapped in the same quote character, otherwise the name is returned as-is.
 */
function getTokenReplacement(token: Token, newName: string): string {
  const text = token.text;
  if (text.length >= 2) {
    const first = text[0];
    const last = text[text.length - 1];
    if ((first === '"' && last === '"') || (first === "'" && last === "'")) {
      return first + newName + last;
    }
  }
  return newName;
}

/**
 * Walks a module's declaration tree and returns the `name` Token of the
 * declaration whose name span contains `position`.
 * Returns null when the position is not inside any declaration name.
 * Used for the case where the cursor sits on a definition rather than a
 * reference (i.e. `findDefinition` returned null).
 */
function findDeclarationNameAtPosition(
  module: Module,
  position: number,
): Token | null {
  function tokenContainsPos(token: Token): boolean {
    return (
      token.position <= position &&
      position < token.position + token.text.length
    );
  }

  function searchInRecord(record: any): Token | null {
    const nameToken = record.name as Token;
    if (tokenContainsPos(nameToken)) return nameToken;
    for (const field of record.fields as Array<{ name: Token }>) {
      if (tokenContainsPos(field.name)) return field.name;
    }

    for (const nested of record.nestedRecords as any[]) {
      const found = searchInRecord(nested);
      if (found) return found;
    }
    return null;
  }

  for (const decl of module.declarations) {
    if (decl.kind === "import") continue; // Import has no single name token
    if (tokenContainsPos(decl.name)) return decl.name;
    if (decl.kind === "record") {
      const found = searchInRecord(decl);
      if (found) return found;
    }
  }
  return null;
}

const fileContentManager = new FileContentManager(skirLanguageExtension);

// VS Code extension activation
// Terminals shared across command invocations
let genWatchTerminal: vscode.Terminal | undefined;
let snapshotTerminal: vscode.Terminal | undefined;

function getOrCreateTerminal(
  existing: vscode.Terminal | undefined,
  name: string,
  cwd: string,
): vscode.Terminal {
  if (existing) {
    existing.show();
    return existing;
  }
  return vscode.window.createTerminal({ name, cwd });
}

function getSkirYmlDir(uri: vscode.Uri): string {
  return path.dirname(uri.fsPath);
}

export async function activate(
  context: vscode.ExtensionContext,
): Promise<void> {
  console.log("Skir Language Support extension is now active");

  // Register skir.yml context-menu commands (before async operations so they
  // are always available even if the workspace scan fails or takes time)
  const genWatchDisposable = vscode.commands.registerCommand(
    "skir.genWatch",
    (uri: vscode.Uri) => {
      const cwd = getSkirYmlDir(uri);
      genWatchTerminal = getOrCreateTerminal(
        genWatchTerminal,
        "Skir: gen --watch",
        cwd,
      );
      genWatchTerminal.show();
      genWatchTerminal.sendText("npx skir gen --watch");
    },
  );

  const snapshotDisposable = vscode.commands.registerCommand(
    "skir.snapshot",
    (uri: vscode.Uri) => {
      const cwd = getSkirYmlDir(uri);
      snapshotTerminal = getOrCreateTerminal(
        snapshotTerminal,
        "Skir: snapshot",
        cwd,
      );
      snapshotTerminal.show();
      snapshotTerminal.sendText("npx skir snapshot");
    },
  );

  const snapshotDryRunDisposable = vscode.commands.registerCommand(
    "skir.snapshotDryRun",
    (uri: vscode.Uri) => {
      const cwd = getSkirYmlDir(uri);
      snapshotTerminal = getOrCreateTerminal(
        snapshotTerminal,
        "Skir: snapshot",
        cwd,
      );
      snapshotTerminal.show();
      snapshotTerminal.sendText("npx skir snapshot --dry-run");
    },
  );

  const snapshotViewDisposable = vscode.commands.registerCommand(
    "skir.snapshotView",
    (uri: vscode.Uri) => {
      const cwd = getSkirYmlDir(uri);
      snapshotTerminal = getOrCreateTerminal(
        snapshotTerminal,
        "Skir: snapshot",
        cwd,
      );
      snapshotTerminal.show();
      snapshotTerminal.sendText("npx skir snapshot --view");
    },
  );

  // Clear terminal references when terminals are closed
  const onDidCloseTerminalDisposable = vscode.window.onDidCloseTerminal(
    (terminal) => {
      if (terminal === genWatchTerminal) {
        genWatchTerminal = undefined;
      } else if (terminal === snapshotTerminal) {
        snapshotTerminal = undefined;
      }
    },
  );

  // Handle .skir file renames/moves: offer to update imports in other files.
  const renameFilesDisposable = vscode.workspace.onDidRenameFiles(
    async (event) => {
      const skirRenames = event.files.filter(
        (f) =>
          f.oldUri.toString().endsWith(".skir") &&
          f.newUri.toString().endsWith(".skir"),
      );
      if (skirRenames.length === 0) return;

      // Build a lookup so edits targeting a file that was *also* renamed in
      // this batch are redirected to the new URI.
      const oldToNew = new Map<string, string>(
        skirRenames.map(({ oldUri, newUri }) => [
          oldUri.toString(),
          newUri.toString(),
        ]),
      );

      // Collect all import update edits across all renamed files.
      const allEdits = new Map<string, vscode.TextEdit[]>();
      for (const { oldUri, newUri } of skirRenames) {
        const edits = skirLanguageExtension.buildImportUpdateEdits(
          oldUri.toString(),
          newUri.toString(),
        );
        for (const [uri, fileEdits] of edits) {
          // If the file that contains the import was also renamed, apply the
          // edits to its new location instead.
          const targetUri = oldToNew.get(uri) ?? uri;
          const existing = allEdits.get(targetUri) ?? [];
          allEdits.set(targetUri, [...existing, ...fileEdits]);
        }
      }

      if (allEdits.size === 0) return;

      const totalFiles = allEdits.size;
      const answer = await vscode.window.showInformationMessage(
        `Update imports in ${totalFiles} file${totalFiles !== 1 ? "s" : ""}?`,
        "Update Imports",
        "Skip",
      );
      if (answer !== "Update Imports") return;

      const workspaceEdit = new vscode.WorkspaceEdit();
      for (const [uri, edits] of allEdits) {
        workspaceEdit.set(vscode.Uri.parse(uri), edits);
      }
      await vscode.workspace.applyEdit(workspaceEdit);
    },
  );

  // Perform initial scan of workspace
  await fileContentManager.runScan();

  // Register definition provider for skir files
  const definitionProvider = new SkirDefinitionProvider(skirLanguageExtension);
  const definitionDisposable = vscode.languages.registerDefinitionProvider(
    { scheme: "file", language: "skir" },
    definitionProvider,
  );

  // Register hover provider for skir files
  const hoverProvider = new SkirHoverProvider(skirLanguageExtension);
  const hoverDisposable = vscode.languages.registerHoverProvider(
    { scheme: "file", language: "skir" },
    hoverProvider,
  );

  // Register references provider for skir files
  const referenceProvider = new SkirReferenceProvider(skirLanguageExtension);
  const referenceDisposable = vscode.languages.registerReferenceProvider(
    { scheme: "file", language: "skir" },
    referenceProvider,
  );

  // Register rename provider for skir files
  const renameProvider = new SkirRenameProvider(skirLanguageExtension);
  const renameDisposable = vscode.languages.registerRenameProvider(
    { scheme: "file", language: "skir" },
    renameProvider,
  );

  // Register completion provider for skir files.
  const completionProvider = new SkirCompletionProvider(skirLanguageExtension);
  const completionDisposable = vscode.languages.registerCompletionItemProvider(
    { scheme: "file", language: "skir" },
    completionProvider,
    ".",
    "|",
    "'",
    '"',
    "/",
    "[",
  );

  // Register document formatting provider for skir files
  const formattingProvider = new SkirFormattingProvider(skirLanguageExtension);
  const formattingDisposable =
    vscode.languages.registerDocumentFormattingEditProvider(
      { scheme: "file", language: "skir" },
      formattingProvider,
    );

  // Register format on save handler
  const formatOnSaveDisposable = vscode.workspace.onWillSaveTextDocument(
    async (event) => {
      if (event.document.languageId === "skir") {
        // Format the document before saving
        const edits = formattingProvider.provideDocumentFormattingEdits(
          event.document,
        );

        if (edits && edits.length > 0) {
          const workspaceEdit = new vscode.WorkspaceEdit();
          workspaceEdit.set(event.document.uri, edits);
          event.waitUntil(vscode.workspace.applyEdit(workspaceEdit));
        }
      }
    },
  );

  // Add to subscriptions for proper cleanup
  context.subscriptions.push(
    fileContentManager,
    definitionDisposable,
    hoverDisposable,
    referenceDisposable,
    renameDisposable,
    completionDisposable,
    formattingProvider,
    formattingDisposable,
    formatOnSaveDisposable,
    genWatchDisposable,
    snapshotDisposable,
    snapshotDryRunDisposable,
    snapshotViewDisposable,
    onDidCloseTerminalDisposable,
    renameFilesDisposable,
  );
}

interface MutableErrorsAndWarnings {
  readonly errors: SkirError[];
  readonly warnings: SkirError[];
}

interface ErrorsAndWarnings {
  readonly errors: readonly SkirError[];
  readonly warnings: readonly SkirError[];
}

const ERRORS_WARNINGS: ReadonlyArray<keyof ErrorsAndWarnings> = [
  "errors",
  "warnings",
];

export function deactivate(): void {
  fileContentManager.dispose();
}
