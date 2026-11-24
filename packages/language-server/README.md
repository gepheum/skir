# Skir Language Server

A [Language Server Protocol (LSP)](https://microsoft.github.io/language-server-protocol/) implementation for the [Skir](https://skir.build/) schema language. Enables IDE features in Vim, Neovim, Emacs, and any other LSP-aware editor.

## Features

| Feature | Description |
|---|---|
| **Diagnostics** | Syntax and type errors, config validation, and breaking-change warnings (when a snapshot is present) |
| **Go to definition** | Jump to the declaration of any type, field, constant, or method |
| **Find references** | List every usage of a symbol across the workspace |
| **Hover** | Show documentation comments for records, fields, methods and constants |
| **Completion** | Context-aware completions with auto-import of types from other modules |
| **Rename** | Rename a symbol and update all references across the workspace |
| **Formatting** | Format the current `.skir` file on save or on demand |
| **File rename** | Automatically update `import` paths in other files when a `.skir` file is renamed (via `willRenameFiles`) |

## Requirements

- **Node.js ≥ 22.12.0** (required for `require()` of ES modules used by the Skir compiler)
- A Skir workspace with a `skir.yml` file

## Installation

```bash
npm install -g skir-language-server
```

Or use it locally inside a project:

```bash
npm install --save-dev skir-language-server
```

## Usage

The server communicates over **stdio** (the standard mode used by most editors):

```bash
skir-language-server --stdio
```

Or directly via `npx` without a global installation:

```bash
npx skir-language-server --stdio
```

---

## Editor configuration

### Neovim (nvim-lspconfig)

Add the following to your Neovim configuration (e.g. `~/.config/nvim/lua/plugins/skir.lua`):

```lua
local lspconfig = require("lspconfig")
local configs = require("lspconfig.configs")

if not configs.skir then
  configs.skir = {
    default_config = {
      cmd = { "npx", "skir-language-server", "--stdio" },
      filetypes = { "skir" },
      root_dir = lspconfig.util.root_pattern("skir.yml"),
      settings = {},
    },
  }
end

lspconfig.skir.setup({})
```

You also need a filetype detection rule. Add to `~/.config/nvim/lua/filetypes.lua` (or `filetype.vim`):

```lua
vim.filetype.add({ extension = { skir = "skir" } })
```

### Neovim (using mason-lspconfig or manual setup)

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "skir",
  callback = function()
    vim.lsp.start({
      name = "skir",
      cmd = { "npx", "skir-language-server", "--stdio" },
      root_dir = vim.fs.dirname(vim.fs.find("skir.yml", { upward = true })[1]),
    })
  end,
})
```

### coc.nvim

Add to your `coc-settings.json`:

```json
{
  "languageserver": {
    "skir": {
      "command": "npx",
      "args": ["skir-language-server", "--stdio"],
      "filetypes": ["skir"],
      "rootPatterns": ["skir.yml"]
    }
  }
}
```

### Vim (vim-lsp)

```vim
if executable('npx')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'skir',
    \ 'cmd': {server_info -> ['npx', 'skir-language-server', '--stdio']},
    \ 'whitelist': ['skir'],
    \ })
endif
```

Also add filetype detection if `.skir` is not yet recognized:

```vim
autocmd BufRead,BufNewFile *.skir setfiletype skir
```

### Emacs (eglot)

```elisp
(add-to-list 'auto-mode-alist '("\\.skir\\'" . skir-mode))
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(skir-mode . ("npx" "skir-language-server" "--stdio"))))
```

### Emacs (lsp-mode)

```elisp
(lsp-register-client
 (make-lsp-client
  :new-connection (lsp-stdio-connection '("npx" "skir-language-server" "--stdio"))
  :major-modes '(skir-mode)
  :server-id 'skir-ls))
```

### Helix

Add to `~/.config/helix/languages.toml`:

```toml
[[language]]
name = "skir"
scope = "source.skir"
file-types = ["skir"]
roots = ["skir.yml"]
language-servers = ["skir-language-server"]

[language-server.skir-language-server]
command = "npx"
args = ["skir-language-server", "--stdio"]
```

### Sublime Text (LSP package)

In *Preferences → Package Settings → LSP → Settings*, add:

```json
{
  "clients": {
    "skir": {
      "command": ["npx", "skir-language-server", "--stdio"],
      "enabled": true,
      "selector": "source.skir"
    }
  }
}
```

---

## Syntax highlighting

The `grammars/` directory contains syntax highlighting definitions for several editors. Copy or symlink the relevant file(s) into your editor's configuration.

| Editor | File | Notes |
|---|---|---|
| **Vim / Neovim** | `grammars/vim/` | Drop the `ftdetect/`, `ftplugin/`, and `syntax/` subdirectories into `~/.vim/` or `~/.config/nvim/` |
| **Emacs** | `grammars/emacs/skir-mode.el` | Load or `require` this file in your Emacs config |
| **Helix** | `grammars/helix/languages.toml` | Merge into `~/.config/helix/languages.toml` |
| **Sublime Text** | `grammars/sublime/skir.sublime-syntax` | Copy to your Sublime Text `Packages/User/` directory |
| **TextMate / VS Code** | `grammars/textmate/skir.tmLanguage.json` | Use as a TextMate grammar or bundle into a VS Code extension |

---

## How it works

The server scans the workspace for:

| File | Purpose |
|---|---|
| `skir.yml` | Workspace definition and dependency declarations |
| `skir-src/**/*.skir` | Source modules |
| `skir-snapshot.json` | Snapshot baseline for breaking-change detection |
| `skir-external/dependencies.json` | Pre-downloaded external dependency modules |

It uses the same compiler internals as the official Skir CLI (`skir` npm package) to parse, type-check, and resolve all modules. Diagnostics are published as LSP `textDocument/publishDiagnostics` notifications.

---

## Building from source

```bash
npm install
npm run build
```

The compiled server is at `dist/server.js`.
# skir-language-server
