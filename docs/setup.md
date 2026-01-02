# Getting started: setup and workflow

## Prerequisites

The Skir compiler requires [Node.js](https://nodejs.org/en/download) to be installed.

## Setting up a project

### Initialize a project

From your project directory, run:
```bash
npx skir init
```

This command creates:
-   `skir.yml`: the Skir configuration file
-   `skir-src/hello_world.skir`: an example `.skir` file

### Configure code generation

The `skir.yml` file controls how Skir generates code for your project. It contains the following top-level properties:

-   `srcDir`: The directory containing your `.skir` files. Defaults to `./skir-src`. Paths are relative to the directory containing `skir.yml` (the root directory).

-    `generators`: An array of code generators to run, one for each target language. All entries are commented out by default. Uncomment the languages you want to target.

Every generator entry has the following properties:

-    `mod`: Identifies the code generator to run (e.g., `skir-python-gen` for Python).
-    `outDir`: The output directory for generated source code (e.g., `./src/skirout`). The directory must be named `skirout`. Do not edit this directory manually — Skir manages its contents entirely. Typically, you'll place this directory at the root of your source tree, but there can be exceptions: in a TypeScript project for example, it's often more convenient to place `skirout` adjacent to the `src` directory. Multiple generators can write to the same output directory, producing source code in different languages. If you specify an array of strings instead of a single string, the generator will write to multiple output directories, which is useful when you have multiple sub-projects in the same language and they need to share the same data types.
-    `config`: Generator-specific configuration. Use `{}` for default settings.

## Core workflow

Run Skir code generation before compiling your language-specific source code.

Use `npx skir gen` to compile your `.skir` files into the target languages specified in your configuration. This creates or updates your `skirout` directories containing the generated source code.

For automatic regeneration, run `npx skir gen --watch`. The compiler will monitor your source directory and regenerate code whenever you modify a `.skir` file.

## Formatting `.skir` files

Use `npx skir format` to format all `.skir` files in your project.

## Continuous integration (GitHub)

We recommend adding `skirout` to `.gitignore` and running Skir code generation in your GitHub workflow. GitHub's hosted runners (Ubuntu, Windows, and macOS) come with Node.js and `npx` pre-installed, so you only need to add one step:

```yml
      - name: Run Skir codegen
        run: npx skir gen
```

If you have a formatting check step, it may fail on Skir-generated code. You can either run the formatting check before Skir codegen, or configure your formatter to skip `skirout` directories.

Consider adding these optional steps for stricter validation:

```yml
      - name: "[Skir] format check"
        run: npx skir format --ci

      - name: "[Skir] snapshot up-to-date"
        run: npx skir snapshot --ci
```

The first step ensures `.skir` files are properly formatted. The second step verifies that you ran `npx skir snapshot` before committing. See [Schema evolution & compatibility](./compatibility.md) for more information about the snapshot command.

## IDE support

The official VS Code [extension](https://marketplace.visualstudio.com/items?itemName=TylerFibonacci.skir-language) for Skir provides syntax highlighting, validation, jump-to-definition, and other language features.
