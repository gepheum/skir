# Building a code generator

Skir code generators are regular NPM modules loaded by the compiler. This page focuses on the integration contract: what your generator must export, what input it receives, and what output it must return.

## How generators are loaded

In `skir.yml`, each generator is declared under `generators` with a `mod` field:

```yaml [skir.yml]
generators:
  - mod: my-company-skir-gen
    out:
      path: generated/my-target
    config:
      myOption: true
```

The value of `mod` is an NPM module name. In practice, this means you can publish your generator package to NPM, then reference that package name directly from `skir.yml`.

## Dependencies

Your generator package should depend on `skir-internal`, because this package defines the public compiler/plugin contract types (for example `CodeGenerator`, `Module`, and `RecordLocation`). Most generators also depend on `zod` for `configType` validation.

```bash
npm i skir-internal zod
```

## Required module export

Your package should export a single generator object named `GENERATOR` that implements the `CodeGenerator<Config>` interface:

```typescript
import { type CodeGenerator } from "skir-internal";
import { z } from "zod";

const Config = z.strictObject({
  // generator-specific options
  myOption: z.boolean(),
});

type Config = z.infer<typeof Config>;

class MyGenerator implements CodeGenerator<Config> {
  readonly id = "my-company-skir-gen";
  readonly configType = Config;

  generateCode(input: CodeGenerator.Input<Config>): CodeGenerator.Output {
    return {
      files: [{ path: "example.txt", code: "generated" }],
    };
  }
}

export const GENERATOR = new MyGenerator();
```

## Input contract

The compiler calls `generateCode(input)`, where `input` has this structure:

```typescript
interface CodeGeneratorInput<Config> {
  readonly modules: readonly Module[];
  readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>;
  readonly config: Config;
}
```

### modules

`modules` contains the parsed schema modules after resolution. Each module gives you the declarations you need for generation:

- `path`: module path (for example `foo/bar.skir`)
- `records`: all structs/enums in that module (top-level and nested)
- `methods`: method declarations with resolved request/response types
- `constants`: constants with resolved types and dense JSON values
- `pathToImportedNames`: map keyed by imported module path; each value indicates which names are imported (or that all names are imported under an alias)

### recordMap

`recordMap` maps every `RecordKey` to a `RecordLocation`. This lookup is important because `ResolvedType` identifies record types with `RecordKey`, not `RecordLocation`. In other words, generators use `recordMap` to resolve a key into the full record metadata, including cross-module references. A `RecordLocation` includes:

- `record`: the record definition
- `recordAncestors`: nesting chain from top-level record to the target record
- `modulePath`: source module where the record is defined

### config

`config` is your generator-specific config object, validated with `configType` (a Zod schema). Keep this schema strict so invalid user config is rejected early.

## Output contract

Your generator returns a list of output files:

```typescript
interface CodeGeneratorOutput {
  readonly files: readonly {
    readonly path: string;
    readonly code: string;
  }[];
}
```

Each entry is one generated file. `path` is the output relative path and `code` is the final file contents.

Generators do not write files to disk directly. They only return the `(path, code)` list; the compiler is responsible for materializing those files.

## Scope of this contract

The compiler/generator contract defines data flow and types. How you map that input into language-specific APIs, classes, or style conventions is generator-specific and intentionally outside this contract.

> [!NOTE]
> A good first step is to inspect an existing generator (for example [skir-rust-gen](https://github.com/gepheum/skir/tree/main/packages/compiler/src/generators/rust) ) and focus on how it consumes `modules`, `recordMap`, and `config`.
