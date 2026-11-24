# skir-codemirror-plugin

This library provides a CodeMirror-based editor for editing Skir value in readable JSON format.

Demo: `npx skir-studio-demo`

## What It Provides

- A ready-to-use `createEditorState(...)` factory for CodeMirror.
- Schema-driven JSON template generation (when no JSON value is provided).
- JSON validation and lint diagnostics.
- In-editor hints and completions informed by the Skir type schema.
- Read-only mode support for response viewing.
- Built-in theme support:
	- all presets from `@uiw/codemirror-themes-all`
	- custom theme object
- Optional `otherExtension` hook to append your own CodeMirror extension(s).

Theme previews and names:
https://www.npmjs.com/package/@uiw/codemirror-themes-all?activeTab=readme

## Install

```sh
npm install skir-codemirror-plugin
```

## Public API

The package root exports:

- `createEditorState`
- `ensureJsonState`
- `toJson`
- `CreateEditorStateParams` (type)
- `BuiltinThemeName` (type)
- `CustomTheme` (type)
- `JsonState` (type)
- all types from `./json/types`

## Usage

```ts
import { EditorView } from "@codemirror/view";
import {
	createEditorState,
	type CreateEditorStateParams,
} from "skir-codemirror-plugin";

const params: CreateEditorStateParams = {
	schema: {
		type: { kind: "primitive", value: "string" },
		records: [],
	},
	// Optional:
	// readOnly: true,
	// json: "hello",
	// theme: "github-light",
	// otherExtension: EditorView.lineWrapping,
};

const state = createEditorState(params);

new EditorView({
	state,
	parent: document.getElementById("editor")!,
});
```

## Read Current JSON Value

Use `ensureJsonState(view, schema)` to force parse/validation against the current
document and retrieve the latest state. Then call `toJson(...)` on
`parseResult.value` when it exists.

```ts
import { EditorView } from "@codemirror/view";
import {
	createEditorState,
	ensureJsonState,
	toJson,
	type TypeDefinition,
} from "skir-codemirror-plugin";

const schema: TypeDefinition = {
	type: { kind: "primitive", value: "string" },
	records: [],
};

const view = new EditorView({
	state: createEditorState({ schema }),
	parent: document.getElementById("editor")!,
});

const jsonState = ensureJsonState(view, schema);

if (jsonState.parseResult.value) {
	const jsonValue = toJson(jsonState.parseResult.value);
	console.log("Current JSON value:", jsonValue);
} else {
	console.log("Cannot convert to JSON:", jsonState.parseResult.errors);
}
```

## createEditorState Parameters

```ts
{
	schema: TypeDefinition,
	readOnly?: true,
	json?: Json,
	theme?: BuiltinThemeName | CustomTheme,
	otherExtension?: Extension,
}
```

Behavior:

- `schema` is required and drives validation/completion.
- If `json` is omitted, a JSON template is generated from the schema.
- `readOnly: true` enables non-editable mode.
- `theme` defaults to `tokyo-night`.
- `theme` accepts any built-in preset name from `BuiltinThemeName` (powered by `@uiw/codemirror-themes-all`) or a custom theme object.
	See available theme previews in the package README:
	https://www.npmjs.com/package/@uiw/codemirror-themes-all?activeTab=readme
- `otherExtension` appends extra CodeMirror extension(s) at the end of the editor extension list.

## Local Dev Flow

This repository includes a minimal local dev page for previewing the editor state produced by `createEditorState`.

### Run It

```sh
npm run dev
```

This does three things:

1. Builds TypeScript sources into `dist/`.
2. Builds the dev entry point from `dev/main.ts` into `dev-dist/main.js`.
3. Starts `web-dev-server` and opens `/dev/index.html`.

Dev URL:

```text
http://localhost:8080/dev/index.html
```

### Dev Files

- `dev/index.html`: minimal host page containing only `#editor` and module import.
- `dev/main.ts`: creates `EditorView` with `createEditorState(...)`.
- `dev-dist/main.js`: generated browser output from `dev/main.ts`.

To try your own schema/JSON inputs, edit `dev/main.ts` and change the `params` object.

### Auto Rebuild and Reload

`npm run dev` watches both:

- `src/**/*.ts` -> rebuilds the library into `dist/`
- `dev/**/*.ts` -> rebuilds the dev entry into `dev-dist/`

`web-dev-server --watch` reloads the page when served files change.

### Dev-Only Note

This flow is for local development only.

- Dev sources are in `dev/`.
- Dev compiled output is in `dev-dist/`.
- Package distribution uses `dist/` as the runtime entrypoint.
