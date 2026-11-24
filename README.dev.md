# Skir Monorepo Maintainer Guide

## 1. Repository Layout

- **`packages/`** — npm workspaces (built & tested together from the root):
  - `packages/compiler-internal` (`skir-internal`): Shared AST, CodeGenerator interface, and casing/hashing helpers.
  - `packages/compiler` (`skir`): The Skir CLI, schema compiler, language server core, and **all 14 built-in language code generators** (`src/generators/<lang>`).
  - `packages/typescript-client` (`skir-client`): TypeScript/JavaScript runtime client library.
  - `packages/codemirror-plugin` (`skir-codemirror-plugin`): CodeMirror 6 editor integration.
  - `packages/studio` (`skir-studio`): Skir Studio web UI component.
  - `packages/converter` (`skir-converter`): Skir format converter web UI.
  - `packages/language-server` (`skir-language-server`): Standalone LSP server for Vim/Neovim/Emacs.
  - `packages/vscode` (`skir-language`, private): VS Code extension.
  - `packages/website` (`@skir/website`, private): Next.js documentation website (`skir.build`).
- **`client-libraries/`** — Non-TypeScript runtime client libraries (`cc`, `csharp`, `dart`, `gleam`, `go`, `kotlin`, `moonbit`, `moonbit-async`, `python`, `python-sqlalchemy`, `rust`, `swift`, `zig`).
- **`e2e-tests/`** — Polyglot end-to-end tests for all language code generators, linked directly against local `client-libraries/<lang>`.
- **`examples/`** — Single-language and multi-language example projects.
- **`docs/languages/`** — Per-language generated code guides.

---

## 2. Everyday Commands

```bash
# Install all npm workspace dependencies
npm install

# Build all TypeScript packages in topological order
npm run build

# Run all fast TypeScript unit tests (compiler, generators, skir-client, studio, codemirror)
npm test

# Run E2E tests for a single language (builds compiler, runs `skir gen`, runs language test suite)
./e2e-tests/test.sh --lang=typescript
./e2e-tests/test.sh --lang=rust
./e2e-tests/test.sh --lang=python

# Run full E2E suite across all 13 languages
./e2e-tests/test.sh
```

---

## 3. Publishing

1. **npm packages (`skir`, `skir-internal`, `skir-client`, `skir-codemirror-plugin`, `skir-studio`, `skir-converter`, `skir-language-server`):**
   - Bump `"version"` in the target `packages/<pkg>/package.json`.
   - Trigger `.github/workflows/publish-npm.yml` manually in GitHub Actions (`workflow_dispatch`, which auto-detects and publishes only packages whose version is not yet on npm), or run `npm publish --workspace=<package-name>` locally.
2. **Polyglot client libraries (`client-libraries/<lang>`):**
   - Trigger the corresponding `.github/workflows/publish-client-<lang>.yml` workflow manually from the GitHub Actions UI (`workflow_dispatch`).
