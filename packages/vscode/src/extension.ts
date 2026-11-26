import * as path from "path";
import * as vscode from "vscode";
import {
  LanguageClient,
  type LanguageClientOptions,
  type ServerOptions,
  TransportKind,
} from "vscode-languageclient/node";

let client: LanguageClient | undefined;

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

  // Register skir.yml context-menu commands
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

  context.subscriptions.push(
    genWatchDisposable,
    snapshotDisposable,
    snapshotDryRunDisposable,
    snapshotViewDisposable,
    onDidCloseTerminalDisposable,
  );

  // Resolve the Skir Language Server entrypoint from the workspace/dependency package
  const serverModule = require.resolve("skir-language-server");

  const serverOptions: ServerOptions = {
    run: {
      module: serverModule,
      transport: TransportKind.ipc,
    },
    debug: {
      module: serverModule,
      transport: TransportKind.ipc,
      options: {
        execArgv: ["--nolazy", "--inspect=6009"],
      },
    },
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [
      { scheme: "file", language: "skir" },
      { scheme: "file", pattern: "**/skir.yml" },
      { scheme: "file", pattern: "**/skir-snapshot.json" },
      { scheme: "file", pattern: "**/skir-external/dependencies.json" },
    ],
    synchronize: {
      fileEvents: [
        vscode.workspace.createFileSystemWatcher("**/*.skir"),
        vscode.workspace.createFileSystemWatcher("**/skir.yml"),
        vscode.workspace.createFileSystemWatcher("**/skir-snapshot.json"),
        vscode.workspace.createFileSystemWatcher(
          "**/skir-external/dependencies.json",
        ),
      ],
    },
    middleware: {
      workspace: {
        willRenameFiles: async (event, next) => {
          const edit = await next(event);
          if (!edit || edit.size === 0) {
            return edit;
          }
          const totalFiles = edit.size;
          const answer = await vscode.window.showInformationMessage(
            `Update imports in ${totalFiles} file${totalFiles !== 1 ? "s" : ""}?`,
            "Update Imports",
            "Skip",
          );
          return answer === "Update Imports" ? edit : undefined;
        },
      },
    },
  };

  client = new LanguageClient(
    "skirLanguageServer",
    "Skir Language Server",
    serverOptions,
    clientOptions,
  );

  await client.start();
  context.subscriptions.push(client);
}

export async function deactivate(): Promise<void> {
  if (client) {
    await client.stop();
    client = undefined;
  }
}
