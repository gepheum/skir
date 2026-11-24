import { CodeBlock, Note, Prose } from '@/components/prose'

export const metadata = {
  title: 'Building a Code Generator - Skir Documentation',
  description: 'Understand the contract between the Skir compiler and custom code generators.',
}

export default function CodeGeneratorsPage() {
  return (
    <Prose>
      <h1>Building a code generator</h1>
      <p>
        Skir code generators are regular NPM modules loaded by the compiler. This page focuses on
        the integration contract: what your generator must export, what input it receives, and what
        output it must return.
      </p>

      <h2>How generators are loaded</h2>
      <p>
        In <code>skir.yml</code>, each generator is declared under <code>generators</code> with a{' '}
        <code>mod</code> field:
      </p>
      <CodeBlock language="yaml" filename="skir.yml">{`generators:
  - mod: my-company-skir-gen
    out:
      path: generated/my-target
    config:
      myOption: true`}</CodeBlock>
      <p>
        The value of <code>mod</code> is an NPM module name. In practice, this means you can publish
        your generator package to NPM, then reference that package name directly from{' '}
        <code>skir.yml</code>.
      </p>

      <h2>Dependencies</h2>
      <p>
        Your generator package should depend on <code>skir-internal</code>, because this package
        defines the public compiler/plugin contract types (for example <code>CodeGenerator</code>,{' '}
        <code>Module</code>, and <code>RecordLocation</code>). Most generators also depend on{' '}
        <code>zod</code> for <code>configType</code> validation.
      </p>
      <CodeBlock language="bash">{`npm i skir-internal zod`}</CodeBlock>

      <h2>Required module export</h2>
      <p>
        Your package should export a single generator object named <code>GENERATOR</code> that
        implements the <code>CodeGenerator&lt;Config&gt;</code> interface:
      </p>
      <CodeBlock language="typescript">{`import { type CodeGenerator } from "skir-internal";
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
      files: [
        { path: "example.txt", code: "generated" },
      ],
    };
  }
}

export const GENERATOR = new MyGenerator();`}</CodeBlock>

      <h2>Input contract</h2>
      <p>
        The compiler calls <code>generateCode(input)</code>, where <code>input</code> has this
        structure:
      </p>
      <CodeBlock language="typescript">{`interface CodeGeneratorInput<Config> {
  readonly modules: readonly Module[];
  readonly recordMap: ReadonlyMap<RecordKey, RecordLocation>;
  readonly config: Config;
}`}</CodeBlock>

      <h3>modules</h3>
      <p>
        <code>modules</code> contains the parsed schema modules after resolution. Each module gives
        you the declarations you need for generation:
      </p>
      <ul>
        <li>
          <code>path</code>: module path (for example <code>foo/bar.skir</code>)
        </li>
        <li>
          <code>records</code>: all structs/enums in that module (top-level and nested)
        </li>
        <li>
          <code>methods</code>: method declarations with resolved request/response types
        </li>
        <li>
          <code>constants</code>: constants with resolved types and dense JSON values
        </li>
        <li>
          <code>pathToImportedNames</code>: map keyed by imported module path; each value indicates
          which names are imported (or that all names are imported under an alias)
        </li>
      </ul>

      <h3>recordMap</h3>
      <p>
        <code>recordMap</code> maps every <code>RecordKey</code> to a <code>RecordLocation</code>.
        This lookup is important because <code>ResolvedType</code> identifies record types with{' '}
        <code>RecordKey</code>, not <code>RecordLocation</code>. In other words, generators use
        <code>recordMap</code> to resolve a key into the full record metadata, including
        cross-module references. A <code>RecordLocation</code> includes:
      </p>
      <ul>
        <li>
          <code>record</code>: the record definition
        </li>
        <li>
          <code>recordAncestors</code>: nesting chain from top-level record to the target record
        </li>
        <li>
          <code>modulePath</code>: source module where the record is defined
        </li>
      </ul>

      <h3>config</h3>
      <p>
        <code>config</code> is your generator-specific config object, validated with{' '}
        <code>configType</code> (a Zod schema). Keep this schema strict so invalid user config is
        rejected early.
      </p>

      <h2>Output contract</h2>
      <p>Your generator returns a list of output files:</p>
      <CodeBlock language="typescript">{`interface CodeGeneratorOutput {
  readonly files: readonly {
    readonly path: string;
    readonly code: string;
  }[];
}`}</CodeBlock>
      <p>
        Each entry is one generated file. <code>path</code> is the output relative path and{' '}
        <code>code</code> is the final file contents.
      </p>
      <p>
        Generators do not write files to disk directly. They only return the{' '}
        <code>(path, code)</code> list; the compiler is responsible for materializing those files.
      </p>

      <h2>Scope of this contract</h2>
      <p>
        The compiler/generator contract defines data flow and types. How you map that input into
        language-specific APIs, classes, or style conventions is generator-specific and
        intentionally outside this contract.
      </p>

      <Note type="info">
        <p>
          A good first step is to inspect an existing generator (for example
          <a
            href="https://github.com/gepheum/skir-rust-gen"
            target="_blank"
            rel="noopener noreferrer"
          >
            {' '}
            skir-rust-gen
          </a>
          ) and focus on how it consumes <code>modules</code>, <code>recordMap</code>, and{' '}
          <code>config</code>.
        </p>
      </Note>
    </Prose>
  )
}
