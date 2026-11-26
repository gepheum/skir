#!/usr/bin/env node
/**
 * Skir Language Server
 *
 * Implements the Language Server Protocol (LSP) for the Skir schema language,
 * providing IDE features (diagnostics, go-to-definition, hover, completion,
 * find-references, rename, and formatting) for Vim/Neovim, Emacs, and any
 * other LSP-aware editor.
 *
 * Run with:  node ./dist/server.js --stdio
 */

// ─── Node stdlib ─────────────────────────────────────────────────────────────
import * as fsPromises from "fs/promises";
import { glob } from "glob";
import { fileURLToPath, pathToFileURL } from "url";

// ─── Skir compiler ───────────────────────────────────────────────────────────
import type { Module, SkirError, Token } from "skir-internal";
import {
  checkCompatibility,
  getTokenForBreakingChange,
} from "skir/dist/compatibility_checker.js";
import { provideCompletionItems as skirProvideCompletionItems } from "skir/dist/completion_helper.js";
import type { SkirConfig } from "skir/dist/config.js";
import {
  parseSkirConfig,
  type SkirConfigError,
} from "skir/dist/config_parser.js";
import { findDefinition, findReferences } from "skir/dist/definition_finder.js";
import { getShortMessageForBreakingChange } from "skir/dist/error_renderer.js";
import { formatModule } from "skir/dist/formatter.js";
import { formatImportBlock } from "skir/dist/import_block_formatter.js";
import { ModuleSet } from "skir/dist/module_set.js";
import type { Packages } from "skir/dist/package_types.js";
import { snapshotFileContentToModuleSet } from "skir/dist/snapshotter.js";

// ─── LSP protocol ────────────────────────────────────────────────────────────
import { TextDocument } from "vscode-languageserver-textdocument";
import {
  createConnection,
  DiagnosticSeverity,
  DidChangeWatchedFilesNotification,
  ErrorCodes,
  FileChangeType,
  Location,
  MarkupKind,
  ProposedFeatures,
  ResponseError,
  TextDocuments,
  TextDocumentSyncKind,
  TextEdit,
  WatchKind,
  type CompletionItem,
  type Diagnostic,
  type Hover,
  type InitializeParams,
  type InitializeResult,
  type LocationLink,
  type Range,
  type WorkspaceEdit,
} from "vscode-languageserver/node";

// ─── Domain-model types ───────────────────────────────────────────────────────

interface FileContent {
  content: string;
  /** Mtime in milliseconds */
  lastModified: number;
}

interface ModuleWorkspace {
  readonly workspace: Workspace;
  readonly modulePath: string;
  astTree?: Module;
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

// ─── PositionTracker ──────────────────────────────────────────────────────────

/**
 * Tracks line-break offsets so that byte offsets can be quickly converted to
 * (line, character) pairs and vice-versa.
 */
class PositionTracker {
  private readonly lineBreaks: number[];

  constructor(private readonly text: string) {
    this.lineBreaks = PositionTracker.findLineBreaks(text);
  }

  private static findLineBreaks(text: string): number[] {
    const breaks: number[] = [0];
    for (let i = 0; i < text.length; i++) {
      const ch = text[i];
      if (ch === "\n") {
        breaks.push(i + 1);
      } else if (ch === "\r") {
        if (i + 1 < text.length && text[i + 1] === "\n") {
          breaks.push(i + 2);
          i++;
        } else {
          breaks.push(i + 1);
        }
      }
    }
    return breaks;
  }

  /** Converts a byte offset to a zero-based (line, column) pair. */
  getPosition(offset: number): { line: number; column: number } {
    const clamped = Math.max(0, Math.min(offset, this.text.length));
    let left = 0;
    let right = this.lineBreaks.length - 1;
    let lineIndex = 0;
    while (left <= right) {
      const mid = Math.floor((left + right) / 2);
      if (this.lineBreaks[mid]! <= clamped) {
        lineIndex = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }
    if (
      lineIndex < this.lineBreaks.length - 1 &&
      clamped >= this.lineBreaks[lineIndex + 1]!
    ) {
      lineIndex++;
    }
    return { line: lineIndex, column: clamped - this.lineBreaks[lineIndex]! };
  }

  /** Converts an LSP Position (zero-based line + character) to a byte offset. */
  offsetAt(line: number, character: number): number {
    if (line < 0) return 0;
    if (line >= this.lineBreaks.length) return this.text.length;
    return this.lineBreaks[line]! + character;
  }
}

// ─── Workspace ────────────────────────────────────────────────────────────────

class Workspace {
  readonly srcUri: string;
  readonly externalUri: string;
  readonly skirYmlUri: string;

  // key: module path; does NOT include dependency modules
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
  private lastResolvedModuleSet: ModuleSet | undefined;
  private changedSinceLastResolution = false;

  constructor(
    readonly rootUri: string,
    public skirConfig: SkirConfigBundle,
    private readonly sendDiagnostics: (
      uri: string,
      diagnostics: Diagnostic[],
    ) => void,
  ) {
    this.srcUri = rootUri + "skir-src/";
    this.externalUri = rootUri + "skir-external/";
    this.skirYmlUri = rootUri + "skir.yml";
  }

  static addModule(
    moduleBundle: ModuleBundle,
    moduleWorkspace: ModuleWorkspace,
  ): void {
    Workspace.removeModule(moduleBundle);
    const { workspace } = moduleWorkspace;
    moduleBundle.moduleWorkspace = moduleWorkspace;
    workspace.modules.set(moduleWorkspace.modulePath, moduleBundle);
    workspace.changedSinceLastResolution = true;
    workspace.scheduleResolution();
  }

  static removeModule(moduleBundle: ModuleBundle): void {
    const { moduleWorkspace } = moduleBundle;
    if (!moduleWorkspace) return;
    const { workspace } = moduleWorkspace;
    workspace.modules.delete(moduleWorkspace.modulePath);
    moduleBundle.moduleWorkspace = undefined;
    workspace.changedSinceLastResolution = true;
    workspace.scheduleResolution();
  }

  get dependencies(): Dependencies | undefined {
    return this.dependenciesData;
  }

  setDependencies(dependencies: Dependencies | undefined): {
    readonly oldModules: readonly ModuleBundle[];
    readonly newModules: readonly ModuleBundle[];
  } {
    const oldDependencies = this.dependenciesData;
    if (oldDependencies) {
      const moduleUris = new Set<string>();
      for (const error of oldDependencies.moduleSet.errors) {
        moduleUris.add(this.getModuleForToken(error.token).moduleUri);
      }
      for (const uri of moduleUris) {
        this.sendDiagnostics(uri, []);
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
          if (error.errorIsInOtherModule) continue;
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
          content: { content, lastModified: 0 },
          positionTracker,
          moduleWorkspace: { workspace: this, modulePath },
        };
        this.dependencyModules.set(modulePath, moduleBundle);
        newModules.push(moduleBundle);
        const errors = modulePathToErrors.get(modulePath) ?? {
          errors: [],
          warnings: [],
        };
        this.sendDiagnostics(
          moduleUri,
          errorsToDiagnostics(errors, moduleBundle),
        );
      }
      dependenciesInSync = Object.entries(
        this.skirConfig.config.dependencies,
      ).every(
        ([pkgId, version]) => dependencies.packages[pkgId]?.version === version,
      );
    } else {
      dependenciesInSync = true;
    }

    this.sendDiagnostics(
      this.skirYmlUri,
      dependenciesInSync
        ? []
        : [
            {
              range: zeroRange(),
              message: "Dependencies out of sync; run npx skir gen",
              severity: DiagnosticSeverity.Warning,
            },
          ],
    );
    this.changedSinceLastResolution = true;
    this.scheduleResolution();
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
    const scheduledResolution = {
      timeout: undefined as unknown as NodeJS.Timeout,
      promise: Promise.resolve(),
      callback: (() => {
        throw new Error("callback not set");
      }) as () => void,
    };
    scheduledResolution.promise = new Promise<void>((resolve) => {
      scheduledResolution.callback = resolve;
    });
    scheduledResolution.timeout = setTimeout(() => {
      this.resolve();
    }, 500);
    this.scheduledResolution = scheduledResolution;
  }

  get resolutionDone(): Promise<void> {
    return this.scheduledResolution?.promise ?? Promise.resolve();
  }

  revolveNow(): void {
    if (this.scheduledResolution) {
      clearTimeout(this.scheduledResolution.timeout);
    }
    this.resolve();
  }

  private resolve(): void {
    const {
      dependenciesData: deps,
      lastSnapshotData: snapshot,
      modules,
    } = this;
    try {
      if (!this.changedSinceLastResolution) return;

      const moduleMap = new Map<string, string>();
      for (const [modulePath, bundle] of modules.entries()) {
        if (!modulePath.startsWith("@")) {
          moduleMap.set(modulePath, bundle.content.content);
        }
      }
      if (deps) {
        for (const pkg of Object.values(deps.packages)) {
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
        const bundle =
          modules.get(modulePath) ?? this.dependencyModules.get(modulePath);
        if (!bundle) continue;
        const errors = parsedModule.errors.filter(
          (e) => !e.errorIsInOtherModule,
        );
        const warnings = parsedModule.warnings ?? [];
        anyError = anyError || errors.length > 0;
        const { moduleWorkspace } = bundle;
        if (moduleWorkspace) {
          moduleWorkspace.astTree = parsedModule.result;
        }
        this.sendDiagnostics(
          bundle.uri,
          errorsToDiagnostics({ errors, warnings }, bundle),
        );
      }
      this.lastResolvedModuleSet = moduleSet;

      if (anyError || !snapshot) return;

      // Check for breaking changes against the last snapshot.
      const breakingChanges = checkCompatibility({
        before: snapshot.moduleSet,
        after: moduleSet,
      });
      const uriToDiagnostics = new Map<string, Diagnostic[]>();
      for (const bc of breakingChanges) {
        const token = getTokenForBreakingChange(bc);
        if (!token) continue;
        const modulePath = token.line.modulePath;
        const moduleUri = this.modulePathToUri(modulePath);
        const bundle = this.getModule(modulePath);
        if (!bundle) continue;
        const range = tokenToRange(token, bundle.positionTracker);
        const message =
          "Breaking change: " +
          getShortMessageForBreakingChange(bc, snapshot.moduleSet);
        const existing = uriToDiagnostics.get(moduleUri) ?? [];
        if (existing.length === 0) uriToDiagnostics.set(moduleUri, existing);
        existing.push({ range, message, severity: DiagnosticSeverity.Warning });
      }
      for (const [uri, diags] of uriToDiagnostics) {
        this.sendDiagnostics(uri, diags);
      }
    } catch (error) {
      console.error("Error during resolution:", error);
    } finally {
      this.scheduledResolution?.callback();
      this.scheduledResolution = undefined;
      this.changedSinceLastResolution = false;
    }
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
      modulePath,
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
        .replace(/\.readonly\.skir$/, ".skir")
        .split("/")
        .map(decodeURIComponent)
        .join("/");
    } else {
      throw new Error(`Invalid module URI: ${uri}`);
    }
  }

  modulePathToUri(modulePath: string): string {
    if (modulePath.startsWith(this.rootUri)) {
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

  getResolvedModules(): readonly Module[] {
    const { lastResolvedModuleSet } = this;
    return lastResolvedModuleSet
      ? [...lastResolvedModuleSet.modules.values()].map((m) => m.result)
      : [];
  }

  getLastResolvedModuleSet(): ModuleSet | undefined {
    return this.lastResolvedModuleSet;
  }

  /**
   * Returns text edits that update import paths in all modules within this
   * workspace after one or more .skir files are renamed.
   * The map is keyed by file URI; renamed files themselves are excluded.
   */
  makeImportEditsForModulePathChanges(
    excludedUris: ReadonlySet<string>,
    oldToNewModulePath: ReadonlyMap<string, string>,
  ): Map<string, TextEdit[]> {
    const result = new Map<string, TextEdit[]>();
    if (oldToNewModulePath.size === 0) return result;
    for (const bundle of this.modules.values()) {
      if (excludedUris.has(bundle.uri)) continue;
      const module = bundle.moduleWorkspace?.astTree;
      if (!module) continue;

      let changed = false;
      const newImports = { ...module.pathToImportedNames };
      for (const [oldModulePath, newModulePath] of oldToNewModulePath) {
        if (oldModulePath in newImports) {
          newImports[newModulePath] = newImports[oldModulePath]!;
          delete newImports[oldModulePath];
          changed = true;
        }
      }
      if (!changed) continue;

      const newImportBlock = formatImportBlock(newImports);
      const { importBlockRange } = module;
      const { positionTracker } = bundle;
      const start = positionTracker.getPosition(importBlockRange!.start);
      const end = positionTracker.getPosition(importBlockRange!.end);
      result.set(bundle.uri, [
        TextEdit.replace(
          makeRange(start.line, start.column, end.line, end.column),
          newImportBlock,
        ),
      ]);
    }
    return result;
  }
}

// ─── SkirEngine ───────────────────────────────────────────────────────────────

/**
 * Core language engine – a direct port of SkirLanguageExtension from the
 * VSCode extension, adapted to use a plain sendDiagnostics callback and LSP
 * types instead of the vscode API.
 */
class SkirEngine {
  constructor(
    private readonly sendDiagnostics: (
      uri: string,
      diagnostics: Diagnostic[],
    ) => void,
  ) {}

  setFileContent(uri: string, content: FileContent | undefined): void {
    const fileType = getFileType(uri);
    if (fileType && !content) {
      this.sendDiagnostics(uri, []);
    }
    switch (fileType) {
      case "skir.yml": {
        if (content) {
          const result = parseSkirConfig(content.content);
          if (result.errors.length === 0) {
            const configBundle: SkirConfigBundle = {
              config: result.skirConfig!,
              yamlContent: content,
            };
            const existing = this.workspaces.get(uri);
            if (existing) {
              existing.skirConfig = configBundle;
              this.setDependencies(existing, existing.dependencies);
            } else {
              const ws = new Workspace(
                uri.replace(/skir\.yml$/, ""),
                configBundle,
                this.sendDiagnostics,
              );
              this.workspaces.set(uri, ws);
              this.scheduleReassignModules();
            }
          } else {
            this.sendDiagnostics(uri, configErrorsToDiagnostics(result.errors));
          }
        } else {
          if (this.workspaces.delete(uri)) {
            this.scheduleReassignModules();
          }
        }
        break;
      }
      case "*.skir": {
        const timeout = this.uriToDebounce.get(uri);
        if (timeout) {
          clearTimeout(timeout);
          this.uriToDebounce.delete(uri);
        }
        const existing = this.moduleBundles.get(uri);
        if (existing) {
          Workspace.removeModule(existing);
          this.moduleBundles.delete(uri);
        }
        if (content) {
          const bundle = this.makeModuleBundle(content, uri);
          const ws = this.findModuleWorkspace(bundle);
          this.moduleBundles.set(uri, bundle);
          if (ws) Workspace.addModule(bundle, ws);
        }
        break;
      }
      case "skir-snapshot.json": {
        const wsUri = uri.replace(/\/skir-snapshot\.json$/, "/skir.yml");
        const ws = this.workspaces.get(wsUri);
        if (ws) ws.setLastSnapshot(undefined);
        if (content && ws) {
          const moduleSetOrError = snapshotFileContentToModuleSet(
            content.content,
          );
          if (moduleSetOrError instanceof ModuleSet) {
            ws.setLastSnapshot({
              moduleSet: moduleSetOrError,
              jsonContent: content,
            });
          } else {
            console.error(`Failed to parse snapshot: ${uri}`);
          }
        }
        break;
      }
      case "dependencies.json": {
        const wsUri = uri.replace(
          /\/skir-external\/dependencies\.json$/,
          "/skir.yml",
        );
        const ws = this.workspaces.get(wsUri);
        if (ws) this.setDependencies(ws, undefined);
        if (content && ws) {
          let packages: Packages;
          try {
            packages = JSON.parse(content.content) as Packages;
          } catch (e) {
            console.error(`Failed to parse dependencies: ${uri}`, e);
            break;
          }
          const depMap = new Map<string, string>();
          for (const pkg of Object.values(packages)) {
            for (const [path, src] of Object.entries(pkg.modules)) {
              depMap.set(path, src);
            }
          }
          this.setDependencies(ws, {
            moduleSet: ModuleSet.compile(depMap, "no-cache", "strict"),
            jsonContent: content,
            packages,
          });
        }
        break;
      }
      default: {
        const _: null = fileType;
      }
    }
  }

  getFileContent(uri: string): FileContent | undefined {
    const fileType = getFileType(uri);
    switch (fileType) {
      case "dependencies.json": {
        const wsUri = uri.replace(
          /\/skir-external\/dependencies\.json$/,
          "/skir.yml",
        );
        return this.workspaces.get(wsUri)?.dependencies?.jsonContent;
      }
      case "*.skir":
        return this.moduleBundles.get(uri)?.content;
      case "skir-snapshot.json": {
        const wsUri = uri.replace(/\/skir-snapshot\.json$/, "/skir.yml");
        return this.workspaces.get(wsUri)?.lastSnapshot?.jsonContent;
      }
      case "skir.yml":
        return this.workspaces.get(uri)?.skirConfig.yamlContent;
      case null:
        return undefined;
      default: {
        const _: never = fileType;
      }
    }
  }

  scheduleSetFileContent(uri: string, content: string): void {
    const old = this.uriToDebounce.get(uri);
    if (old) clearTimeout(old);
    const timeout = setTimeout(() => {
      this.uriToDebounce.delete(uri);
      try {
        this.setFileContent(uri, { content, lastModified: Date.now() });
      } catch (e) {
        console.error(`Error setting file content for ${uri}:`, e);
      }
    }, 100);
    this.uriToDebounce.set(uri, timeout);
  }

  getModuleBundle(uri: string): ModuleBundle | undefined {
    return this.moduleBundles.get(uri);
  }

  findDefinitionAt(uri: string, offset: number): LocationLink[] | null {
    const bundle = this.moduleBundles.get(uri);
    if (!bundle?.moduleWorkspace) return null;
    const { workspace } = bundle.moduleWorkspace;
    workspace.revolveNow();
    const module = bundle.moduleWorkspace.astTree;
    if (!module) return null;

    const match = findDefinition(module, offset);
    if (!match) return null;

    const { modulePath, declaration, referenceToken } = match;
    const targetUri = workspace.modulePathToUri(modulePath);
    let targetRange: Range;

    if (declaration) {
      const targetBundle = this.moduleBundles.get(targetUri);
      if (!targetBundle) return null;
      targetRange = tokenToRange(
        declaration.name,
        targetBundle.positionTracker,
      );
    } else {
      targetRange = makeRange(0, 0, 0, 0);
    }

    return [
      {
        targetUri,
        targetRange,
        targetSelectionRange: targetRange,
        originSelectionRange: tokenToRange(
          referenceToken,
          bundle.positionTracker,
        ),
      },
    ];
  }

  getHoverInfo(uri: string, offset: number): Hover | null {
    const bundle = this.moduleBundles.get(uri);
    const module = bundle?.moduleWorkspace?.astTree;
    if (!module) return null;

    const match = findDefinition(module, offset);
    if (!match?.declaration) return null;
    const { declaration } = match;
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

    return {
      contents: { kind: MarkupKind.PlainText, value: docText },
    };
  }

  findAllReferences(uri: string, offset: number): Location[] {
    const result = this.getDefinitionToken(uri, offset);
    if (!result) return [];
    const { definitionToken, workspace } = result;
    workspace.revolveNow();
    const resolvedModules = workspace.getResolvedModules();
    const refs = findReferences(definitionToken, resolvedModules);
    return refs
      .map((t) => this.tokenToLocation(t, workspace))
      .filter((l): l is Location => l !== null);
  }

  getCompletionItems(
    uri: string,
    offset: number,
    moduleContent: string,
  ): CompletionItem[] {
    const bundle = this.moduleBundles.get(uri);
    if (!bundle?.moduleWorkspace) return [];
    const { workspace, modulePath } = bundle.moduleWorkspace;
    const oldModuleSet = workspace.getLastResolvedModuleSet();
    if (!oldModuleSet) return [];

    const result = skirProvideCompletionItems(
      modulePath,
      moduleContent,
      offset,
      oldModuleSet,
    );
    if (!result) return [];

    // Build the "placeholder" range (the token being replaced) from the
    // CURRENT module content, not the last-resolved one.
    const pt = new PositionTracker(moduleContent);
    const startPos = pt.getPosition(result.placeholderStartPos);
    const endPos = pt.getPosition(result.placeholderEndPos);
    const placeholderRange = makeRange(
      startPos.line,
      startPos.column,
      endPos.line,
      endPos.column,
    );

    return result.items.map((item): CompletionItem => {
      const insertText = item.insertText ?? item.name;
      const ci: CompletionItem = {
        label: item.name,
        textEdit: TextEdit.replace(placeholderRange, insertText),
      };
      if (item.doc?.text) {
        ci.documentation = {
          kind: MarkupKind.PlainText,
          value: item.doc.text.trim(),
        };
      }
      if (item.modulePath) {
        ci.detail = `Auto-import from "${item.modulePath}"`;
      }
      const { importBlockEdit } = item;
      if (importBlockEdit) {
        const start = pt.getPosition(importBlockEdit.oldStart);
        const end = pt.getPosition(importBlockEdit.oldEnd);
        ci.additionalTextEdits = [
          TextEdit.replace(
            makeRange(start.line, start.column, end.line, end.column),
            importBlockEdit.newText,
          ),
        ];
      }
      return ci;
    });
  }

  prepareRename(
    uri: string,
    offset: number,
  ): { range: Range; placeholder: string } {
    const bundle = this.moduleBundles.get(uri);
    if (!bundle?.moduleWorkspace) {
      throw new Error("Cannot rename: module not found");
    }
    bundle.moduleWorkspace.workspace.revolveNow();
    const module = bundle.moduleWorkspace.astTree;
    if (!module) throw new Error("Cannot rename: no AST");

    const match = findDefinition(module, offset);
    if (match !== null) {
      if (match.declaration === undefined) {
        throw new Error("Cannot rename: no renameable symbol at cursor");
      }
      if (match.modulePath.startsWith("@")) {
        throw new Error(
          "Cannot rename: symbol is defined in an external dependency",
        );
      }
    }

    // Find the word span at the cursor.
    const { content } = bundle.content;
    let start = offset;
    let end = offset;
    while (start > 0 && /[a-zA-Z0-9_]/.test(content[start - 1]!)) start--;
    while (end < content.length && /[a-zA-Z0-9_]/.test(content[end]!)) end++;
    if (start === end) throw new Error("Cannot rename: no symbol at cursor");

    const startPos = bundle.positionTracker.getPosition(start);
    const endPos = bundle.positionTracker.getPosition(end);
    return {
      range: makeRange(
        startPos.line,
        startPos.column,
        endPos.line,
        endPos.column,
      ),
      placeholder: content.slice(start, end),
    };
  }

  provideRenameEdits(
    uri: string,
    offset: number,
    newName: string,
  ): WorkspaceEdit | null {
    const result = this.getDefinitionToken(uri, offset);
    if (!result) return null;
    const { definitionToken, workspace } = result;

    if (definitionToken.line.modulePath.startsWith("@")) return null;

    workspace.revolveNow();
    const refs = findReferences(
      definitionToken,
      workspace.getResolvedModules(),
    );

    const allTokens = [definitionToken, ...refs];
    const changes: Record<string, TextEdit[]> = {};
    for (const token of allTokens) {
      const loc = this.tokenToLocation(token, workspace);
      if (!loc) continue;
      const edits = (changes[loc.uri] ??= []);
      edits.push(
        TextEdit.replace(loc.range, getTokenReplacement(token, newName)),
      );
    }
    return { changes };
  }

  formatDocument(uri: string, liveContent?: string): TextEdit[] {
    const bundle = this.moduleBundles.get(uri);
    if (!bundle?.moduleWorkspace?.modulePath) return [];
    const { modulePath } = bundle.moduleWorkspace;
    const sourceCode = liveContent ?? bundle.content.content;
    const pt =
      liveContent !== undefined
        ? new PositionTracker(sourceCode)
        : bundle.positionTracker;
    const { textEdits } = formatModule({
      sourceCode,
      modulePath,
    });
    return textEdits.map((e) =>
      TextEdit.replace(
        makeRange(...startEndToLineChar(e.oldStart, e.oldEnd, pt)),
        e.newText,
      ),
    );
  }

  /**
   * Builds text edits that update import paths in sibling modules after
   * one or more .skir files are renamed.
   */
  buildImportUpdateEdits(
    renames: ReadonlyArray<{ oldUri: string; newUri: string }>,
  ): Map<string, TextEdit[]> {
    const byWorkspace = new Map<
      Workspace,
      {
        excludedUris: Set<string>;
        oldToNewModulePath: Map<string, string>;
      }
    >();
    for (const { oldUri, newUri } of renames) {
      const ws = this.moduleBundles.get(oldUri)?.moduleWorkspace?.workspace;
      if (!ws) continue;
      let oldPath: string, newPath: string;
      try {
        oldPath = ws.moduleUriToPath(oldUri);
        newPath = ws.moduleUriToPath(newUri);
      } catch {
        continue;
      }
      if (oldPath === newPath) continue;
      let group = byWorkspace.get(ws);
      if (!group) {
        group = {
          excludedUris: new Set(),
          oldToNewModulePath: new Map(),
        };
        byWorkspace.set(ws, group);
      }
      group.excludedUris.add(oldUri);
      group.oldToNewModulePath.set(oldPath, newPath);
    }

    const allEdits = new Map<string, TextEdit[]>();
    for (const [ws, { excludedUris, oldToNewModulePath }] of byWorkspace) {
      ws.revolveNow();
      const wsEdits = ws.makeImportEditsForModulePathChanges(
        excludedUris,
        oldToNewModulePath,
      );
      for (const [uri, edits] of wsEdits) {
        allEdits.set(uri, edits);
      }
    }
    return allEdits;
  }

  /** Removes from memory any tracked files that no longer exist on disk. */
  async runGarbageCollection(): Promise<void> {
    const uris = [...this.moduleBundles.keys()];
    for (const ws of this.workspaces.values()) {
      uris.push(ws.skirYmlUri);
      if (ws.lastSnapshot) uris.push(ws.rootUri + "skir-snapshot.json");
      if (ws.dependencies)
        uris.push(ws.rootUri + "skir-external/dependencies.json");
    }
    for (const uri of uris) {
      let exists = false;
      try {
        const fsPath = fileURLToPath(uri);
        const stat = await fsPromises.stat(fsPath);
        exists = stat.isFile();
      } catch {
        /* file does not exist */
      }
      if (!exists) {
        this.setFileContent(uri, undefined);
      }
    }
  }

  private setDependencies(ws: Workspace, deps: Dependencies | undefined): void {
    const { oldModules, newModules } = ws.setDependencies(deps);
    for (const m of oldModules) this.moduleBundles.delete(m.uri);
    for (const m of newModules) this.moduleBundles.set(m.uri, m);
  }

  private scheduleReassignModules(): void {
    if (this.reassignTimeout) return;
    this.reassignTimeout = setTimeout(() => {
      for (const bundle of this.moduleBundles.values()) {
        if (bundle.isExternalDependency) continue;
        Workspace.removeModule(bundle);
        const ws = this.findModuleWorkspace(bundle);
        if (ws) Workspace.addModule(bundle, ws);
      }
      for (const ws of this.workspaces.values()) ws.scheduleResolution();
      this.reassignTimeout = undefined;
    });
  }

  private makeModuleBundle(content: FileContent, uri: string): ModuleBundle {
    return {
      uri,
      isExternalDependency: false,
      content,
      positionTracker: new PositionTracker(content.content),
    };
  }

  private findModuleWorkspace(
    bundle: ModuleBundle,
  ): ModuleWorkspace | undefined {
    let match: Workspace | undefined;
    for (const ws of this.workspaces.values()) {
      if (bundle.uri.startsWith(ws.rootUri)) {
        if (
          match === undefined ||
          ws.srcUri.length < match.srcUri.length ||
          (ws.srcUri.length === match.srcUri.length && ws.srcUri < match.srcUri)
        ) {
          match = ws;
        }
      }
    }
    if (match) {
      const { srcUri, externalUri } = match;
      if (bundle.uri.startsWith(srcUri) || bundle.uri.startsWith(externalUri)) {
        return {
          workspace: match,
          modulePath: match.moduleUriToPath(bundle.uri),
        };
      }
    }
    const warningMsg = match
      ? "Not in skir-src directory"
      : "No skir workspace found; add a skir.yml file";
    this.sendDiagnostics(bundle.uri, [
      {
        range: zeroRange(),
        message: warningMsg,
        severity: DiagnosticSeverity.Warning,
      },
    ]);
    return undefined;
  }

  private getDefinitionToken(
    uri: string,
    offset: number,
  ): { definitionToken: Token; workspace: Workspace } | null {
    const bundle = this.moduleBundles.get(uri);
    const module = bundle?.moduleWorkspace?.astTree;
    if (!module || !bundle?.moduleWorkspace) return null;
    const { workspace } = bundle.moduleWorkspace;

    const match = findDefinition(module, offset);
    if (match) {
      if (!match.declaration) return null;
      return { definitionToken: match.declaration.name, workspace };
    }
    const token = findDeclarationNameAtPosition(module, offset);
    if (!token) return null;
    return { definitionToken: token, workspace };
  }

  private tokenToLocation(token: Token, workspace: Workspace): Location | null {
    const moduleUri = workspace.modulePathToUri(token.line.modulePath);
    const bundle = this.moduleBundles.get(moduleUri);
    if (!bundle) return null;
    return Location.create(
      moduleUri,
      tokenToRange(token, bundle.positionTracker),
    );
  }

  private reassignTimeout?: NodeJS.Timeout;
  private readonly moduleBundles = new Map<string, ModuleBundle>();
  private readonly workspaces = new Map<string, Workspace>();
  private readonly uriToDebounce = new Map<string, NodeJS.Timeout>();
}

// ─── Free helper functions ────────────────────────────────────────────────────

function getFileType(
  uri: string,
): "skir.yml" | "skir-snapshot.json" | "*.skir" | "dependencies.json" | null {
  if (uri.endsWith("/skir-external/dependencies.json"))
    return "dependencies.json";
  if (/\/skir-external\//.test(uri)) return null;
  if (uri.endsWith("/skir.yml")) return "skir.yml";
  if (uri.endsWith("/skir-snapshot.json")) return "skir-snapshot.json";
  if (uri.endsWith(".skir")) return "*.skir";
  return null;
}

function makeRange(
  startLine: number,
  startChar: number,
  endLine: number,
  endChar: number,
): Range {
  return {
    start: { line: startLine, character: startChar },
    end: { line: endLine, character: endChar },
  };
}

function zeroRange(): Range {
  return makeRange(0, 0, 0, 0);
}

function tokenToRange(token: Token, pt: PositionTracker): Range {
  const start = pt.getPosition(token.position);
  const end = pt.getPosition(token.position + token.originalText.length);
  return makeRange(start.line, start.column, end.line, end.column);
}

/**
 * Returns the four components needed for makeRange from a (start, end) offset
 * pair – saves boilerplate inside formatDocument.
 */
function startEndToLineChar(
  start: number,
  end: number,
  pt: PositionTracker,
): [number, number, number, number] {
  const s = pt.getPosition(start);
  const e = pt.getPosition(end);
  return [s.line, s.column, e.line, e.column];
}

function errorsToDiagnostics(
  errors: ErrorsAndWarnings,
  bundle: ModuleBundle,
): Diagnostic[] {
  const errorToDiagnostic = (
    err: SkirError,
    severity: DiagnosticSeverity,
  ): Diagnostic => ({
    range: tokenToRange(err.token, bundle.positionTracker),
    message: err.message || `expected: ${err.expected}`,
    severity,
  });
  return errors.errors
    .map((err) => errorToDiagnostic(err, DiagnosticSeverity.Error))
    .concat(
      errors.warnings.map((warn) =>
        errorToDiagnostic(warn, DiagnosticSeverity.Warning),
      ),
    );
}

function configErrorsToDiagnostics(
  errors: readonly SkirConfigError[],
): Diagnostic[] {
  return errors.map((e) => ({
    range: e.range
      ? makeRange(
          e.range.start.lineNumber - 1,
          e.range.start.colNumber - 1,
          e.range.end.lineNumber - 1,
          e.range.end.colNumber - 1,
        )
      : zeroRange(),
    message: e.message,
    severity: DiagnosticSeverity.Error,
  }));
}

function getTokenReplacement(token: Token, newName: string): string {
  const t = token.text;
  if (t.length >= 2) {
    const first = t[0]!;
    const last = t[t.length - 1]!;
    if ((first === '"' && last === '"') || (first === "'" && last === "'")) {
      return first + newName + last;
    }
  }
  return newName;
}

/**
 * Walks the declaration tree of a module and returns the name Token of the
 * declaration whose name span contains `position`.  Used when the cursor is on
 * the declaration name itself (findDefinition would return null in that case).
 */
function findDeclarationNameAtPosition(
  module: Module,
  position: number,
): Token | null {
  const contains = (t: Token): boolean =>
    t.position <= position && position < t.position + t.text.length;

  function searchRecord(record: {
    name: Token;
    fields: ReadonlyArray<{ name: Token }>;
    nestedRecords: readonly unknown[];
  }): Token | null {
    if (contains(record.name)) return record.name;
    for (const field of record.fields) {
      if (contains(field.name)) return field.name;
    }
    for (const nested of record.nestedRecords as (typeof record)[]) {
      const found = searchRecord(nested);
      if (found) return found;
    }
    return null;
  }

  for (const decl of module.declarations) {
    if (decl.kind === "import") continue;
    if (contains(decl.name)) return decl.name;
    if (decl.kind === "record") {
      const found = searchRecord(decl as Parameters<typeof searchRecord>[0]);
      if (found) return found;
    }
  }
  return null;
}

/** Sort priority for initial file load order (skir.yml must come before modules). */
function fileLoadTier(uri: string): number {
  if (uri.endsWith("/skir.yml")) return 1;
  if (uri.endsWith("/dependencies.json")) return 2;
  return 3;
}

// ─── LSP server setup ─────────────────────────────────────────────────────────

const connection = createConnection(ProposedFeatures.all);
const textDocuments = new TextDocuments(TextDocument);

let workspaceRootUris: string[] = [];
let supportsWatchedFilesRegistration = false;

const engine = new SkirEngine((uri, diagnostics) => {
  connection.sendDiagnostics({ uri, diagnostics });
});

// Track whether the initial scan has been performed so we can do light-weight
// re-scans when watched files change.
let initialScanDone = false;

// ── initialize ────────────────────────────────────────────────────────────────

connection.onInitialize((params: InitializeParams): InitializeResult => {
  // Collect workspace root URIs.
  if (params.workspaceFolders && params.workspaceFolders.length > 0) {
    workspaceRootUris = params.workspaceFolders.map((f) => f.uri);
  } else if (params.rootUri) {
    workspaceRootUris = [params.rootUri];
  }

  supportsWatchedFilesRegistration =
    params.capabilities.workspace?.didChangeWatchedFiles
      ?.dynamicRegistration === true;

  const result: InitializeResult = {
    capabilities: {
      textDocumentSync: {
        openClose: true,
        change: TextDocumentSyncKind.Incremental,
        willSaveWaitUntil: true,
        save: { includeText: false },
      },
      definitionProvider: true,
      referencesProvider: true,
      hoverProvider: true,
      completionProvider: {
        triggerCharacters: [".", "|", "'", '"', "/", "["],
        resolveProvider: false,
      },
      renameProvider: { prepareProvider: true },
      documentFormattingProvider: true,
      workspace: {
        fileOperations: {
          willRename: {
            filters: [{ pattern: { glob: "**/*.skir", matches: "file" } }],
          },
        },
      },
    },
  };
  return result;
});

// ── initialized ───────────────────────────────────────────────────────────────

connection.onInitialized(async () => {
  // Register dynamic file watchers so the client notifies us when
  // .skir / config files change on disk (works for Neovim, coc.nvim, etc.).
  if (supportsWatchedFilesRegistration) {
    await connection.client.register(DidChangeWatchedFilesNotification.type, {
      watchers: [
        {
          globPattern: "**/*.skir",
          kind: WatchKind.Create | WatchKind.Change | WatchKind.Delete,
        },
        {
          globPattern: "**/skir.yml",
          kind: WatchKind.Create | WatchKind.Change | WatchKind.Delete,
        },
        {
          globPattern: "**/skir-snapshot.json",
          kind: WatchKind.Create | WatchKind.Change | WatchKind.Delete,
        },
        {
          globPattern: "**/skir-external/dependencies.json",
          kind: WatchKind.Create | WatchKind.Change | WatchKind.Delete,
        },
      ],
    });
  }

  // Perform the initial workspace scan.
  await runFullScan();
  initialScanDone = true;

  // Start the periodic background scan (garbage-collection + re-scan).
  scheduleScanLoop();
});

// ── text document lifecycle ───────────────────────────────────────────────────

textDocuments.onDidOpen((event) => {
  const uri = event.document.uri;
  if (!getFileType(uri)) return;
  const content = event.document.getText();
  const existing = engine.getFileContent(uri);
  if (!existing || existing.content !== content) {
    engine.setFileContent(uri, { content, lastModified: Date.now() });
  }
});

textDocuments.onDidChangeContent((event) => {
  const uri = event.document.uri;
  if (!getFileType(uri)) return;
  engine.scheduleSetFileContent(uri, event.document.getText());
});

textDocuments.onDidClose((event) => {
  const uri = event.document.uri;
  // Re-read from disk to ensure engine reflects the saved state.
  void readFileIntoEngine(uri);
});

// ── watched file changes ──────────────────────────────────────────────────────

connection.onDidChangeWatchedFiles(async (params) => {
  for (const change of params.changes) {
    const { uri, type } = change;
    if (!getFileType(uri)) continue;
    if (type === FileChangeType.Deleted) {
      engine.setFileContent(uri, undefined);
    } else {
      // Created or Changed.  If the document is currently open (unsaved edits),
      // trust the textDocuments version.
      if (textDocuments.get(uri)) continue;
      await readFileIntoEngine(uri);
    }
  }
});

// ── definition ───────────────────────────────────────────────────────────────

connection.onDefinition((params) => {
  const { uri } = params.textDocument;
  const offset = getOffset(params.textDocument.uri, params.position);
  try {
    return engine.findDefinitionAt(uri, offset);
  } catch (e) {
    console.error("onDefinition error:", e);
    return null;
  }
});

// ── references ───────────────────────────────────────────────────────────────

connection.onReferences((params) => {
  const { uri } = params.textDocument;
  const offset = getOffset(uri, params.position);
  try {
    return engine.findAllReferences(uri, offset);
  } catch (e) {
    console.error("onReferences error:", e);
    return [];
  }
});

// ── hover ─────────────────────────────────────────────────────────────────────

connection.onHover((params) => {
  const { uri } = params.textDocument;
  const offset = getOffset(uri, params.position);
  try {
    return engine.getHoverInfo(uri, offset);
  } catch (e) {
    console.error("onHover error:", e);
    return null;
  }
});

// ── completion ────────────────────────────────────────────────────────────────

connection.onCompletion((params) => {
  const { uri } = params.textDocument;
  // Use the live editor content if available for more accurate completions.
  const doc = textDocuments.get(uri);
  const content = doc?.getText() ?? engine.getFileContent(uri)?.content ?? "";
  const pt = new PositionTracker(content);
  const offset = pt.offsetAt(params.position.line, params.position.character);
  try {
    return engine.getCompletionItems(uri, offset, content);
  } catch (e) {
    console.error("onCompletion error:", e);
    return [];
  }
});

// ── prepare rename ────────────────────────────────────────────────────────────

connection.onPrepareRename((params) => {
  const { uri } = params.textDocument;
  const offset = getOffset(uri, params.position);
  try {
    return engine.prepareRename(uri, offset);
  } catch (e) {
    return new ResponseError(
      ErrorCodes.InvalidRequest,
      e instanceof Error ? e.message : String(e),
    );
  }
});

// ── rename ────────────────────────────────────────────────────────────────────

connection.onRenameRequest((params) => {
  const { uri } = params.textDocument;
  const offset = getOffset(uri, params.position);
  try {
    return engine.provideRenameEdits(uri, offset, params.newName);
  } catch (e) {
    console.error("onRenameRequest error:", e);
    return null;
  }
});

// ── formatting ────────────────────────────────────────────────────────────────

connection.onDocumentFormatting((params) => {
  const { uri } = params.textDocument;
  try {
    const liveContent = textDocuments.get(uri)?.getText();
    return engine.formatDocument(uri, liveContent);
  } catch (e) {
    console.error("onDocumentFormatting error:", e);
    return [];
  }
});

connection.onWillSaveTextDocumentWaitUntil((params) => {
  const { uri } = params.textDocument;
  if (!uri.endsWith(".skir")) return [];
  try {
    const liveContent = textDocuments.get(uri)?.getText();
    return engine.formatDocument(uri, liveContent);
  } catch (e) {
    console.error("onWillSaveTextDocumentWaitUntil error:", e);
    return [];
  }
});

// ── file rename (willRenameFiles) ─────────────────────────────────────────────

connection.workspace.onWillRenameFiles((params) => {
  const skirRenames = params.files.filter(
    ({ oldUri, newUri }) =>
      oldUri.endsWith(".skir") && newUri.endsWith(".skir"),
  );
  if (skirRenames.length === 0) return null;
  const edits = engine.buildImportUpdateEdits(skirRenames);
  if (edits.size === 0) return null;
  const changes: Record<string, TextEdit[]> = {};
  for (const [fileUri, fileEdits] of edits) {
    changes[fileUri] = fileEdits;
  }
  return { changes };
});

// ─── File scanning ────────────────────────────────────────────────────────────

async function readFileIntoEngine(uri: string): Promise<void> {
  if (!getFileType(uri)) return;
  try {
    const fsPath = fileURLToPath(uri);
    const stat = await fsPromises.stat(fsPath);
    const mtime = stat.mtimeMs;
    const old = engine.getFileContent(uri);
    if (old && old.lastModified >= mtime) return;
    const content = await fsPromises.readFile(fsPath, "utf-8");
    if (old && old.content === content) return;
    engine.setFileContent(uri, { content, lastModified: mtime });
  } catch {
    // File may have been deleted; engine will handle the missing state.
    engine.setFileContent(uri, undefined);
  }
}

async function runFullScan(): Promise<void> {
  for (const rootUri of workspaceRootUris) {
    await scanFolder(rootUri);
  }
}

async function scanFolder(rootUri: string): Promise<void> {
  let rootPath: string;
  try {
    rootPath = fileURLToPath(rootUri);
  } catch {
    // rootUri might not be a file:// URI (e.g. virtual filesystems).
    return;
  }

  const patterns = [
    "**/skir.yml",
    "**/skir-external/dependencies.json",
    "**/*.skir",
    "**/skir-snapshot.json",
  ];

  const allPaths: string[] = [];
  for (const pattern of patterns) {
    try {
      const matches = await glob(pattern, {
        cwd: rootPath,
        absolute: true,
        ignore: ["**/node_modules/**"],
      });
      allPaths.push(...matches);
    } catch (e) {
      console.error(`glob error (${pattern}):`, e);
    }
  }

  // Sort so skir.yml is processed first, then dependencies.json, then modules.
  allPaths.sort(
    (a, b) =>
      fileLoadTier(pathToFileURL(a).toString()) -
      fileLoadTier(pathToFileURL(b).toString()),
  );

  for (const fsPath of allPaths) {
    const uri = pathToFileURL(fsPath).toString();
    // If the document is open in the editor, that version takes precedence.
    if (textDocuments.get(uri)) continue;
    await readFileIntoEngine(uri);
  }
}

function scheduleScanLoop(): void {
  setTimeout(() => void runScanLoopIteration(), 10_000);
}

async function runScanLoopIteration(): Promise<void> {
  try {
    await engine.runGarbageCollection();
    if (initialScanDone) await runFullScan();
  } catch (e) {
    console.error("Scan loop error:", e);
  }
  scheduleScanLoop();
}

// ─── Utility used by request handlers ────────────────────────────────────────

/**
 * Converts an LSP Position to a byte offset using the engine's tracked content
 * for the given URI (falls back to empty document offset = 0).
 */
function getOffset(
  uri: string,
  position: { line: number; character: number },
): number {
  const doc = textDocuments.get(uri);
  if (doc) return doc.offsetAt(position);
  const bundle = engine.getModuleBundle(uri);
  if (!bundle) return 0;
  return bundle.positionTracker.offsetAt(position.line, position.character);
}

// ─── Start ────────────────────────────────────────────────────────────────────

textDocuments.listen(connection);
connection.listen();
