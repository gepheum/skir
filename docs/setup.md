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

The `skir.yml` file controls how Skir generates code for your project. Here's an example:

```yml
# skir.yml

# Directory containing .skir files
srcDir: skir-src

generators:
  - mod: skir-cc-gen
    outDir: ./app/src/skirout
    config:
      writeGoogleTestHeaders: true
  - mod: skir-typescript-gen
    outDir: ./frontend/skirout
    config: {}
```

All paths are relative to the directory containing `skir.yml` (the root directory).

Every generator entry has the following properties:

-    `mod`: Identifies the code generator to run (e.g., `skir-python-gen` for Python).
-    `outDir`: The output directory for generated source code (e.g., `./src/skirout`). The directory **must** be named `skirout`. If you specify an array of strings, the generator will write to multiple output directories, which is useful when you have multiple sub-projects in the same language.
-    `config`: Generator-specific configuration. Use `{}` for default settings.

### Output directory location

Typically, you should place the skirout directory at the root of your sub-project's source tree. However, placement varies by ecosystem to ensure idiomatic results:
-   TypeScript: It's often more convenient to place `skirout` adjacent to the `src` directory.
-   Java / Kotlin / Python: Place the directory inside your top-level package (e.g., `src/main/java/com/myproject/skirout`). This ensures generated package names (like `com.myproject.skirout.*`) follow standard naming conventions.

Multiple generators can write to the same output directory, which means this directory will contain source files in different languages.

> [!WARNING]
> Do not manually edit any of the files inside a `skirout` directory. This directory is managed by Skir. Any manual change will be overwritten during the next generation.

## Core workflow

Run Skir code generation before compiling your language-specific source code.

```shell
npx skir gen
```

This command transpiles your `.skir` files into the target languages specified in your configuration. This creates or updates your `skirout` directories containing the generated source code.

For a more seamless experience, consider using watch mode:

```shell
npx skir gen --watch
```

The compiler will monitor your source directory and automatically regenerate code whenever you modify a `.skir` file.

> [!TIP]
> If your project is a Node project, add add `skir gen` to your `package.json` scripts. Using the `prebuild` hook is recommended so that code is regenerated automatically before every build.
> ```json
{
  "scripts": {
    "prebuild": "skir gen",
    "build": "tsc" 
  }
}```
> *For a full implementation, see this [example project](https://github.com/gepheum/skir-typescript-example/blob/main/package.json).*

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
