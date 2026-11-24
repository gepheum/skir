// TODO: add number of UTF-8 bytes copied

import { json } from "@codemirror/lang-json";
import { EditorState } from "@codemirror/state";
import { minimalSetup } from "codemirror";
import { css, html, LitElement, TemplateResult } from "lit";
import { customElement, query, state } from "lit/decorators.js";
import { getModuleFromGithubUrl } from "skir/dist/get_dependencies_flow.js";
import { AppState, makeZeroState, updateAppState } from "./app-state";
import "./code-mirror";
import { CodeMirror } from "./code-mirror";
import { whiteEditorThemeExtension } from "./editor-theme";
import { recordToTypeDefinition } from "./record-to-type-definition";

@customElement("skir-converter-app")
export class App extends LitElement {
  static override styles = css`
    @import url("https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600;700&family=Press+Start+2P&display=swap");

    :host {
      --bg: #f3f1e8;
      --bg-panel: #fffdf7;
      --bg-panel-2: #efecdf;
      --ink: #111111;
      --muted: #545454;
      --line: #232323;
      --line-bright: #000000;
      --accent: #111111;
      --accent-soft: #e7e3d6;
      --warm: #111111;
      --warm-soft: #faf8f0;
      --ok: #303030;
      --editor-bg: #050505;
      --editor-surface: #0f0f0f;
      --editor-border: #343434;
      --editor-ink: #f5f5f5;
      --editor-muted: #8b8b8b;

      display: block;
      position: relative;
      min-height: 100vh;
      overflow: hidden;
      background:
        radial-gradient(
            circle at 18% 14%,
            rgba(0, 0, 0, 0.14) 0,
            transparent 2px
          )
          0 0 / 38px 38px,
        radial-gradient(
            circle at 74% 26%,
            rgba(0, 0, 0, 0.08) 0,
            transparent 1.5px
          )
          0 0 / 29px 29px,
        linear-gradient(180deg, #fcfaf2 0%, var(--bg) 100%);
      color: var(--ink);
      font-family: "IBM Plex Mono", monospace;
    }

    :host::before,
    :host::after {
      content: "";
      position: absolute;
      inset: 0;
      pointer-events: none;
    }

    :host::before {
      background: linear-gradient(
        180deg,
        transparent,
        rgba(0, 0, 0, 0.025) 45%,
        transparent
      );
      opacity: 0.8;
    }

    :host::after {
      background: repeating-linear-gradient(
        180deg,
        rgba(0, 0, 0, 0.035) 0,
        rgba(0, 0, 0, 0.035) 1px,
        transparent 1px,
        transparent 4px
      );
      opacity: 0.1;
    }

    * {
      box-sizing: border-box;
    }

    main {
      position: relative;
      z-index: 1;
    }

    a {
      color: var(--accent);
    }

    .app-shell {
      max-width: 1240px;
      margin: 0 auto;
      padding: 1rem;
      display: flex;
      flex-direction: column;
      gap: 1rem;
    }

    .top-row {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 1rem;
    }

    .headline {
      border: 2px solid var(--line-bright);
      border-radius: 0;
      background: linear-gradient(180deg, #fffef8 0%, #f1ede0 100%);
      padding: 1rem 1.1rem;
      display: flex;
      align-items: center;
      justify-content: flex-start;
      gap: 1rem;
      box-shadow:
        8px 8px 0 rgba(0, 0, 0, 0.12),
        inset 0 0 0 1px rgba(0, 0, 0, 0.04);
    }

    .brand-lockup {
      min-width: 0;
      display: flex;
      align-items: center;
      gap: 1rem;
    }

    .brand-icon-shell {
      width: 4.5rem;
      height: 4.5rem;
      flex-shrink: 0;
      display: grid;
      place-items: center;
      border: 2px solid var(--accent);
      background: #ffffff;
      box-shadow: 4px 4px 0 rgba(0, 0, 0, 0.12);
    }

    .brand-icon {
      width: 2.8rem;
      height: 2.8rem;
      display: block;
      image-rendering: pixelated;
    }

    .title-wrap {
      display: flex;
      flex-direction: column;
      gap: 0.45rem;
      min-width: 0;
    }

    .headline-link {
      color: inherit;
      text-decoration: none;
    }

    .headline-link:focus-visible {
      outline: 2px solid var(--accent);
      outline-offset: 4px;
      border-radius: 6px;
    }

    h1 {
      margin: 0;
      font-family: "Press Start 2P", monospace;
      font-size: clamp(0.96rem, 2vw, 1.45rem);
      line-height: 1.45;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      text-shadow: 2px 2px 0 rgba(0, 0, 0, 0.08);
    }

    .subtitle {
      margin: 0;
      color: var(--muted);
      max-width: 46rem;
      font-size: 0.82rem;
      line-height: 1.5;
    }

    .panel {
      border: 2px solid var(--line);
      border-radius: 0;
      background: var(--bg-panel);
      box-shadow:
        6px 6px 0 rgba(0, 0, 0, 0.1),
        inset 0 0 0 1px rgba(0, 0, 0, 0.03);
      overflow: hidden;
    }

    .top-panel {
      display: flex;
      flex-direction: column;
      height: 340px;
    }

    .panel-head {
      border-bottom: 1px solid var(--line-bright);
      padding: 0.8rem 0.95rem;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 0.75rem;
      background: repeating-linear-gradient(
        180deg,
        #f7f3e7 0,
        #f7f3e7 2px,
        var(--bg-panel-2) 2px,
        var(--bg-panel-2) 4px
      );
    }

    .panel-head h2 {
      margin: 0;
      font-family: "Press Start 2P", monospace;
      font-size: 0.7rem;
      line-height: 1.4;
      text-transform: uppercase;
      letter-spacing: 0.1em;
    }

    .panel-head p {
      margin: 0;
      font-size: 0.76rem;
      color: var(--muted);
      font-family: "IBM Plex Mono", monospace;
    }

    .panel-body {
      padding: 0.95rem;
      display: flex;
      flex-direction: column;
      gap: 0.9rem;
    }

    .top-panel .panel-body {
      flex: 1;
      min-height: 0;
    }

    .tab-row {
      display: inline-flex;
      width: fit-content;
      border: 1px solid var(--line);
      border-radius: 0;
      padding: 0.2rem;
      background: #ebe7db;
      gap: 0.35rem;
      flex-wrap: wrap;
    }

    .tab-row button {
      border: 1px solid transparent;
      border-radius: 0;
      padding: 0.5rem 0.72rem;
      min-width: 7.5rem;
      cursor: pointer;
      background: transparent;
      color: var(--muted);
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.77rem;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      transition:
        background-color 120ms ease,
        color 120ms ease,
        border-color 120ms ease;
    }

    .tab-row button:hover {
      color: var(--ink);
      border-color: var(--line-bright);
    }

    .tab-row button[aria-selected="true"] {
      background: var(--accent);
      color: #fff;
      border-color: var(--accent);
    }

    .field {
      display: flex;
      flex-direction: column;
      gap: 0.36rem;
    }

    .editor-field {
      position: relative;
    }

    .top-panel .editor-field {
      flex: 1;
      min-height: 0;
    }

    .editor-overlay {
      position: absolute;
      inset: 0;
      z-index: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 0.9rem;
      border: 1px dashed var(--line-bright);
      border-radius: 0;
      background: rgba(255, 253, 247, 0.92);
      color: #111;
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.8rem;
      line-height: 1.5;
      text-align: center;
      cursor: text;
    }

    .editor-overlay span {
      max-width: 22rem;
    }

    .field label {
      font-size: 0.72rem;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      color: var(--muted);
      font-family: "IBM Plex Mono", monospace;
    }

    textarea,
    input,
    select {
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 0;
      background: #fffef9;
      color: var(--ink);
      padding: 0.72rem 0.78rem;
      font-size: 0.84rem;
      font-family: "IBM Plex Mono", monospace;
      outline: none;
      transition:
        border-color 120ms ease,
        box-shadow 120ms ease;
    }

    textarea:focus,
    input:focus,
    select:focus {
      border-color: var(--accent);
      box-shadow: 0 0 0 2px rgba(0, 0, 0, 0.12);
    }

    textarea {
      min-height: 188px;
      resize: vertical;
      line-height: 1.55;
    }

    .compact-area textarea,
    .compact-area .skir-view,
    .compact-area skir-code-mirror {
      min-height: 138px;
    }

    .skir-view {
      min-height: 188px;
      border: 1px solid var(--line);
      border-radius: 0;
      background: linear-gradient(180deg, #101010, #080808);
      padding: 0.8rem;
      display: grid;
      gap: 0.5rem;
      align-content: start;
    }

    .tree-node {
      border: 1px solid var(--line);
      border-radius: 0;
      background: #0a0a0a;
      padding: 0.52rem 0.6rem;
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 0.5rem;
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.78rem;
    }

    .node-type {
      color: var(--muted);
    }

    .hint {
      margin: 0;
      font-size: 0.74rem;
      color: var(--muted);
      line-height: 1.5;
    }

    .divider {
      height: 1px;
      width: 100%;
      background: var(--line);
    }

    .result-panel-body {
      border: 1px solid var(--line);
      border-radius: 0;
      overflow: hidden;
      background: #faf7ee;
    }

    .result-editors {
      display: block;
    }

    .result-editor {
      display: none;
    }

    .result-editor.active {
      display: block;
    }

    .result-message {
      margin: 0;
      padding: 0.75rem;
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.8rem;
      line-height: 1.5;
    }

    .result-message.info {
      color: var(--muted);
      background: #f3eee1;
    }

    .result-message.error {
      color: #111;
      background: #f5e9e9;
    }

    .result-controls {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 0.5rem;
      flex-wrap: wrap;
    }

    .copy-btn {
      border: 1px solid var(--line);
      border-radius: 0;
      background: #fffef9;
      color: var(--ink);
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.72rem;
      padding: 0.42rem 0.72rem;
      cursor: pointer;
      transition:
        background-color 120ms ease,
        color 120ms ease,
        border-color 120ms ease;
    }

    .copy-btn:hover {
      background: var(--accent);
      color: #fff;
      border-color: var(--accent);
    }

    .copy-confirmation {
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.72rem;
      color: var(--ok);
    }

    .copy-wrap {
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }

    .schema-mode-hint {
      margin: 0;
      font-size: 0.74rem;
      color: var(--muted);
      font-family: "IBM Plex Mono", monospace;
    }

    .field-label-row {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 0.5rem;
    }

    .field-help-link {
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.66rem;
      color: var(--accent);
      text-decoration: underline;
    }

    .github-fields {
      display: flex;
      flex-direction: column;
      gap: 0.8rem;
    }

    .github-fetch-btn {
      align-self: flex-start;
      border: 1px solid var(--line);
      border-radius: 0;
      background: #fffef9;
      color: var(--ink);
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.78rem;
      padding: 0.45rem 0.78rem;
      cursor: pointer;
      transition:
        background-color 120ms ease,
        border-color 120ms ease;
      text-transform: uppercase;
      letter-spacing: 0.08em;
    }

    .github-fetch-btn:hover {
      background: var(--accent);
      border-color: var(--accent);
      color: #fff;
    }

    .github-fetch-btn:disabled {
      opacity: 0.6;
      cursor: not-allowed;
      background: #ece7da;
      border-color: var(--line);
    }

    .github-fetch-row {
      display: flex;
      align-items: center;
      gap: 0.6rem;
      flex-wrap: wrap;
    }

    .github-fetch-status {
      font-family: "IBM Plex Mono", monospace;
      font-size: 0.72rem;
      line-height: 1.4;
      padding: 0.28rem 0.5rem;
      border: 1px solid var(--line);
      background: #f5f0e3;
    }

    .github-fetch-status.success {
      color: var(--ok);
    }

    .github-fetch-status.error {
      color: #111;
      background: #f5e9e9;
      border-color: var(--line);
    }

    @media (max-width: 930px) {
      .top-row {
        grid-template-columns: 1fr;
      }

      .headline {
        align-items: flex-start;
        flex-direction: column;
      }

      .brand-lockup {
        align-items: flex-start;
        flex-direction: column;
      }
    }

    @media (max-width: 640px) {
      .app-shell {
        padding: 0.8rem;
      }

      .brand-icon-shell {
        width: 3.8rem;
        height: 3.8rem;
      }

      .brand-icon {
        width: 2.35rem;
        height: 2.35rem;
      }

      .tab-row {
        width: 100%;
      }

      .tab-row button {
        flex: 1 1 10rem;
      }

      .result-controls {
        align-items: stretch;
        flex-direction: column;
      }

      .copy-wrap {
        justify-content: space-between;
      }
    }
  `;

  @state()
  private resultTab: "dense-json" | "readable-json" | "base16" | "base64" =
    "readable-json";

  @state()
  private copied = false;

  @state()
  private schemaOverlayDismissed = false;

  @state()
  private valueOverlayDismissed = false;

  @state()
  private schemaInputMode: "paste-json" | "github" = "paste-json";

  @state()
  private githubUrl = "";

  @state()
  private githubToken = "";

  override render(): TemplateResult {
    type GithubFetchStatus =
      { kind: "success"; message: string } | { kind: "error"; message: string };

    const githubFetchDisabled = this.githubState.kind === "fetching";
    const githubFetchStatus: GithubFetchStatus | undefined =
      this.githubState.kind === "success"
        ? { kind: "success", message: "Fetched schema from GitHub." }
        : this.githubState.kind === "error"
          ? { kind: "error", message: this.githubState.error }
          : undefined;

    return html`
      <main class="app-shell">
        <header class="headline">
          <div class="brand-lockup">
            <div class="brand-icon-shell" aria-hidden="true">
              <img class="brand-icon" src="./converter-favicon.svg" alt="" />
            </div>

            <div class="title-wrap">
              <a class="headline-link" href="/">
                <h1>Skir Converter</h1>
              </a>
              <p class="subtitle">
                Translate schemas and values between dense JSON, readable JSON,
                and binary formats without leaving your browser.
              </p>
            </div>
          </div>
        </header>

        <section class="top-row">
          ${this.renderSchemaPanel(githubFetchDisabled, githubFetchStatus)}
          ${this.renderInputPanel()}
        </section>

        ${this.renderResultsPanel()}
      </main>
    `;
  }

  private renderSchemaPanel(
    githubFetchDisabled: boolean,
    githubFetchStatus:
      | { kind: "success"; message: string }
      | { kind: "error"; message: string }
      | undefined,
  ): TemplateResult {
    return html`
      <section class="panel top-panel">
        <div class="panel-head">
          <h2>Schema</h2>
        </div>

        <div class="panel-body compact-area">
          <div class="tab-row" role="tablist" aria-label="Schema input mode">
            <button
              role="tab"
              aria-selected=${this.schemaInputMode === "paste-json"}
              @click=${(): void => {
                this.schemaInputMode = "paste-json";
              }}
            >
              Type Descriptor
            </button>
            <button
              role="tab"
              aria-selected=${this.schemaInputMode === "github"}
              @click=${(): void => {
                this.schemaInputMode = "github";
              }}
            >
              GitHub
            </button>
          </div>

          <div
            class="field editor-field"
            style=${
              this.schemaInputMode === "paste-json"
                ? "display: flex"
                : "display: none"
            }
          >
            ${
              this.schemaOverlayDismissed
                ? ""
                : html`
                    <div
                      class="editor-overlay"
                      @click=${(): void => {
                        this.dismissOverlay("schema");
                      }}
                    >
                      <span>Paste the type descriptor JSON</span>
                    </div>
                  `
            }
            <skir-code-mirror
              id="schema-json"
              fill-height
              .initialState=${this.makeInputSchemaEditorState("")}
              @text-modified=${(): void => this.onSchemaTextModified()}
            ></skir-code-mirror>
          </div>

          <div
            class="github-fields"
            style=${
              this.schemaInputMode === "github"
                ? "display: flex"
                : "display: none"
            }
          >
            <div class="field">
              <div class="field-label-row">
                <label for="github-url">GitHub file URL</label>
                <a
                  class="field-help-link"
                  href="https://github.com/gepheum/skir-fantasy-game-example/blob/v1.0.0/skir-src/fantasy_game.skir#L123"
                  target="_blank"
                  rel="noopener noreferrer"
                  >Example</a
                >
              </div>
              <input
                id="github-url"
                type="url"
                .value=${this.githubUrl}
                @input=${(event: Event): void => {
                  this.githubUrl = (event.target as HTMLInputElement).value;
                }}
                placeholder="Link to specific line in .skir file"
              />
            </div>

            <div class="field">
              <label for="github-token">GitHub token (optional, risky)</label>
              <input
                id="github-token"
                type="password"
                .value=${this.githubToken}
                @input=${(event: Event): void => {
                  this.githubToken = (event.target as HTMLInputElement).value;
                }}
              />
            </div>

            <div class="github-fetch-row">
              <button
                class="github-fetch-btn"
                type="button"
                ?disabled=${githubFetchDisabled}
                @click=${this.onGithubFetch}
              >
                Fetch
              </button>
              ${
                githubFetchStatus
                  ? html`
                      <span
                        class="github-fetch-status ${githubFetchStatus.kind}"
                        role=${
                          githubFetchStatus.kind === "error"
                            ? "alert"
                            : "status"
                        }
                      >
                        ${githubFetchStatus.message}
                      </span>
                    `
                  : ""
              }
            </div>
          </div>
        </div>
      </section>
    `;
  }

  private renderInputPanel(): TemplateResult {
    return html`
      <section class="panel top-panel">
        <div class="panel-head">
          <h2>Input</h2>
        </div>

        <div class="panel-body compact-area">
          <div class="field editor-field">
            ${
              this.valueOverlayDismissed
                ? ""
                : html`
                    <div
                      class="editor-overlay"
                      @click=${(): void => {
                        this.dismissOverlay("value");
                      }}
                    >
                      <span
                        >Paste the value in JSON form (dense or readale) or
                        binary form (base16 or base64)
                      </span>
                    </div>
                  `
            }
            <skir-code-mirror
              id="input-value"
              fill-height
              .initialState=${EditorState.create({
                extensions: [minimalSetup, whiteEditorThemeExtension, json()],
              })}
              @text-modified=${(): void => this.onValueTextModified()}
            ></skir-code-mirror>
          </div>
        </div>
      </section>
    `;
  }

  private renderResultsPanel(): TemplateResult {
    const result = this.appState.result;

    if (result.kind !== "ok") {
      const infoMessage =
        result.kind === "schema-not-set"
          ? "Schema is not set yet. Paste a schema JSON to compute results."
          : result.kind === "value-not-set"
            ? "Value is not set yet. Paste a value to compute results."
            : undefined;

      const errorMessage =
        result.kind === "schema-error"
          ? result.error
          : result.kind === "value-parse-error"
            ? result.error
            : result.kind === "schema-value-match-error"
              ? result.error
              : undefined;

      return html`
        <section class="panel">
          <div class="panel-head">
            <h2>Result</h2>
          </div>

          <div class="panel-body">
            <div class="result-panel-body">
              ${
                infoMessage
                  ? html`<p class="result-message info">${infoMessage}</p>`
                  : ""
              }
              ${
                errorMessage
                  ? html`<p class="result-message error">${errorMessage}</p>`
                  : ""
              }
            </div>
          </div>
        </section>
      `;
    }

    return html`
      <section class="panel">
        <div class="panel-head">
          <h2>Result</h2>
        </div>

        <div class="panel-body">
          <div class="result-controls">
            <div class="tab-row" role="tablist" aria-label="Result tabs">
              ${this.renderResultTabButton("Readable JSON", "readable-json")}
              ${this.renderResultTabButton("Dense JSON", "dense-json")}
              ${this.renderResultTabButton("Binary (base 16)", "base16")}
              ${this.renderResultTabButton("Binary (base 64)", "base64")}
            </div>
            <div class="copy-wrap">
              ${
                this.copied
                  ? html`<span class="copy-confirmation">Copied!</span>`
                  : ""
              }
              <button
                class="copy-btn"
                @click=${(): void => {
                  navigator.clipboard.writeText(this.getResultText(result));
                  this.copied = true;
                  setTimeout(() => {
                    this.copied = false;
                  }, 2000);
                }}
              >
                Copy
              </button>
            </div>
          </div>

          <div class="result-panel-body">
            <div class="result-editors">
              ${this.renderResultEditor(
                "readable-json",
                "result-readable-json",
                result.readableJsonEditorState,
              )}
              ${this.renderResultEditor(
                "dense-json",
                "result-dense-json",
                result.denseJsonEditorState,
              )}
              ${this.renderResultEditor(
                "base16",
                "result-base16",
                result.base16EditorState,
              )}
              ${this.renderResultEditor(
                "base64",
                "result-base64",
                result.base64EditorState,
              )}
            </div>
          </div>
        </div>
      </section>
    `;
  }

  private renderResultEditor(
    tab: "dense-json" | "readable-json" | "base16" | "base64",
    id: string,
    initialState: EditorState,
  ): TemplateResult {
    return html`
      <div
        class=${
          this.resultTab === tab ? "result-editor active" : "result-editor"
        }
        aria-hidden=${this.resultTab === tab ? "false" : "true"}
      >
        <skir-code-mirror
          id=${id}
          .initialState=${initialState}
        ></skir-code-mirror>
      </div>
    `;
  }

  private renderResultTabButton(
    title: string,
    tab: "dense-json" | "readable-json" | "base16" | "base64",
  ): TemplateResult {
    return html`
      <button
        role="tab"
        aria-selected=${this.resultTab === tab}
        @click=${(): void => {
          this.resultTab = tab;
        }}
      >
        ${title}
      </button>
    `;
  }

  private getResultEditorState(
    tab: "dense-json" | "readable-json" | "base16" | "base64",
    result: Extract<AppState["result"], { kind: "ok" }>,
  ): EditorState {
    if (tab === "dense-json") {
      return result.denseJsonEditorState;
    }
    if (tab === "readable-json") {
      return result.readableJsonEditorState;
    }
    if (tab === "base16") {
      return result.base16EditorState;
    }
    return result.base64EditorState;
  }

  private getResultText(
    result: Extract<AppState["result"], { kind: "ok" }>,
  ): string {
    return this.getResultEditorState(this.resultTab, result).doc.toString();
  }

  updateState(): void {
    const oldState = this.appState;
    let valueText: string;
    if (this.valueTextWasModified) {
      valueText = this.inputValueElement!.state.doc.toString();
      this.valueTextWasModified = false;
    } else {
      valueText = oldState.input.text;
    }
    let schemaText: string;
    if (this.schemaTextWasModified) {
      schemaText = this.inputSchemaElement!.state.doc.toString();
      this.schemaTextWasModified = false;
    } else {
      schemaText = oldState.schema.text;
    }
    const newState = updateAppState(valueText, schemaText, oldState);
    this.appState = newState;
    void this.updateComplete.then(() => {
      this.syncResultEditors(newState);
    });
  }

  private syncResultEditors(state: AppState): void {
    if (state.result.kind !== "ok") {
      return;
    }

    if (this.resultReadableJsonElement) {
      this.resultReadableJsonElement.state =
        state.result.readableJsonEditorState;
    }
    if (this.resultDenseJsonElement) {
      this.resultDenseJsonElement.state = state.result.denseJsonEditorState;
    }
    if (this.resultBase16Element) {
      this.resultBase16Element.state = state.result.base16EditorState;
    }
    if (this.resultBase64Element) {
      this.resultBase64Element.state = state.result.base64EditorState;
    }
  }

  private valueTextWasModified = false;
  private schemaTextWasModified = false;
  private stateUpdateTimeoutHandle: ReturnType<typeof setTimeout> | undefined;

  private onValueTextModified(): void {
    this.valueTextWasModified = true;
    this.scheduleStateUpdate();
  }

  private onSchemaTextModified(): void {
    this.schemaTextWasModified = true;
    this.scheduleStateUpdate();
  }

  private async onGithubFetch(): Promise<void> {
    this.githubState = { kind: "fetching" };
    const githubUrl = this.githubUrlElement!.value;
    const githubToken = this.githubTokenElement!.value;
    const onError = (message: string): void => {
      const newGithubState: GithubState = { kind: "error", error: message };
      this.githubState = newGithubState;
      window.setTimeout(() => {
        if (this.githubState === newGithubState) {
          this.githubState = { kind: "initial" };
        }
      }, 4000);
    };
    try {
      const githubResult = await getModuleFromGithubUrl(githubUrl, githubToken);
      if (githubResult.kind === "success") {
        const schemaText = JSON.stringify(
          recordToTypeDefinition(githubResult.record, githubResult.moduleSet),
          undefined,
          "  ",
        );
        this.inputSchemaElement!.state =
          this.makeInputSchemaEditorState(schemaText);
        this.schemaOverlayDismissed = true;
        this.schemaTextWasModified = true;
        this.updateState();
        const newGithubState: GithubState = { kind: "success" };
        this.githubState = newGithubState;
        window.setTimeout(() => {
          if (this.githubState === newGithubState) {
            this.githubState = { kind: "initial" };
          }
        }, 2000);
      } else {
        onError(githubResult.message);
      }
    } catch (e) {
      if (e instanceof Error) {
        onError(e.message);
      } else {
        onError(String(e));
      }
    }
  }

  private scheduleStateUpdate(): void {
    if (this.stateUpdateTimeoutHandle !== undefined) {
      clearTimeout(this.stateUpdateTimeoutHandle);
    }
    this.stateUpdateTimeoutHandle = setTimeout(() => {
      this.stateUpdateTimeoutHandle = undefined;
      this.updateState();
    }, 100);
  }

  private dismissOverlay(kind: "schema" | "value"): void {
    if (kind === "schema") {
      this.schemaOverlayDismissed = true;
      requestAnimationFrame(() => {
        this.inputSchemaElement?.view.focus();
      });
      return;
    }

    this.valueOverlayDismissed = true;
    requestAnimationFrame(() => {
      this.inputValueElement?.view.focus();
    });
  }

  private makeInputSchemaEditorState(schemaText: string): EditorState {
    return EditorState.create({
      extensions: [minimalSetup, whiteEditorThemeExtension, json()],
      doc: schemaText,
    });
  }

  @query("#input-value")
  inputValueElement: CodeMirror | undefined;
  @query("#schema-json")
  inputSchemaElement: CodeMirror | undefined;
  @query("#github-url")
  githubUrlElement: HTMLInputElement | undefined;
  @query("#github-token")
  githubTokenElement: HTMLInputElement | undefined;
  @query("#result-readable-json")
  resultReadableJsonElement: CodeMirror | undefined;
  @query("#result-dense-json")
  resultDenseJsonElement: CodeMirror | undefined;
  @query("#result-base16")
  resultBase16Element: CodeMirror | undefined;
  @query("#result-base64")
  resultBase64Element: CodeMirror | undefined;

  @state()
  private appState = makeZeroState();
  @state()
  private githubState: GithubState = { kind: "initial" };
}

if (!customElements.get("skir-converter-app")) {
  customElements.define("skir-converter-app", App);
}

declare global {
  interface HTMLElementTagNameMap {
    "skir-converter-app": App;
  }
}

type GithubState =
  | {
      kind: "initial";
    }
  | {
      kind: "fetching";
    }
  | {
      kind: "success";
    }
  | {
      kind: "error";
      error: string;
    };
