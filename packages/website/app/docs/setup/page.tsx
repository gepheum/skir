import { HoverVideo } from '@/components/hover-video'
import { NextPageLink } from '@/components/next-page-link'
import { CodeBlock, Note, Prose } from '@/components/prose'

export const metadata = {
  title: 'Quickstart: setup and workflow - Skir Documentation',
  description: 'Set up Skir in your project and learn the basic workflow.',
}

export default function GettingStartedPage() {
  return (
    <Prose>
      <h1>Quickstart: setup and workflow</h1>

      <h2>Prerequisites</h2>
      <p>
        The Skir compiler requires{' '}
        <a href="https://nodejs.org" target="_blank" rel="noopener noreferrer">
          Node.js
        </a>{' '}
        or{' '}
        <a href="https://bun.sh" target="_blank" rel="noopener noreferrer">
          Bun
        </a>{' '}
        to be installed. If you use Bun, replace <code>npx</code> with <code>bunx</code> in the
        commands below.
      </p>

      <h2>Setting up a project</h2>

      <h3>Initialize a project</h3>
      <p>From your project directory, run:</p>
      <CodeBlock language="bash">{`npx skir init`}</CodeBlock>
      <p>This command creates:</p>
      <ul>
        <li>
          <code>skir.yml</code>: the Skir configuration file
        </li>
        <li>
          <code>skir-src/hello_world.skir</code>: an example <code>.skir</code> file
        </li>
      </ul>

      <h3>Configure code generation</h3>
      <p>
        The <code>skir.yml</code> file controls how Skir generates code for your project. Here's an
        example:
      </p>
      <CodeBlock language="yaml" filename="skir.yml">{`# skir.yml

generators:
  - mod: skir-cc-gen
    outDir: ./app/src/skirout
    config:
      writeGoogleTestHeaders: true
  - mod: skir-typescript-gen
    outDir: ./frontend/skirout
    config: {}`}</CodeBlock>
      <p>
        All paths are relative to the directory containing <code>skir.yml</code> (the root
        directory).
      </p>
      <p>Every generator entry has the following properties:</p>
      <ul>
        <li>
          <strong>mod</strong>: Identifies the code generator to run (e.g.,{' '}
          <code>skir-python-gen</code> for Python).
        </li>
        <li>
          <strong>outDir</strong>: The output directory for generated source code (e.g.,{' '}
          <code>./src/skirout</code>). The directory <strong>must</strong> be named{' '}
          <code>skirout</code>. If you specify an array of strings, the generator will write to
          multiple output directories, which is useful when you have multiple sub-projects in the
          same language.
        </li>
        <li>
          <strong>config</strong>: Generator-specific configuration. Use <code>{'{}'}</code> for
          default settings.
        </li>
      </ul>

      <h3>Output directory location</h3>
      <p>
        Typically, you should place the skirout directory at the root of your sub-project's source
        tree. However, placement varies by ecosystem to ensure idiomatic results:
      </p>
      <ul>
        <li>
          <strong>TypeScript</strong>: It's often more convenient to place <code>skirout</code>{' '}
          adjacent to the <code>src</code> directory.
        </li>
        <li>
          <strong>Java / Kotlin / Python</strong>: Place the directory inside your top-level package
          (e.g., <code>src/main/java/com/myproject/skirout</code>). This ensures generated package
          names (like <code>com.myproject.skirout.*</code>) follow standard naming conventions.
        </li>
      </ul>
      <p>
        Multiple generators can write to the same output directory, which means this directory will
        contain source files in different languages.
      </p>
      <Note type="warning">
        <p>
          Do not manually edit any of the files inside a <code>skirout</code> directory. This
          directory is managed by Skir. Any manual change will be overwritten during the next
          generation.
        </p>
      </Note>

      <h2>Core workflow</h2>
      <p>Run Skir code generation before compiling your language-specific source code.</p>
      <CodeBlock language="bash">{`npx skir gen`}</CodeBlock>
      <p>
        This command transpiles your <code>.skir</code> files into the target languages specified in
        your configuration. This creates or updates your <code>skirout</code> directories containing
        the generated source code.
      </p>
      <p>For a more seamless experience, consider using watch mode:</p>
      <CodeBlock language="bash">{`npx skir gen --watch`}</CodeBlock>
      <p>
        The compiler will monitor your source directory and automatically regenerate code whenever
        you modify a <code>.skir</code> file.
      </p>
      <Note type="tip">
        <p>
          If your project is a Node project, add <code>skir gen</code> to your{' '}
          <code>package.json</code> scripts. Using the <code>prebuild</code> hook is recommended so
          that code is regenerated automatically before every build.
        </p>
      </Note>
      <CodeBlock language="json" filename="package.json">{`{
  "scripts": {
    "prebuild": "skir gen",
    "build": "tsc"
  }
}`}</CodeBlock>

      <h2>Formatting .skir files</h2>
      <p>
        Use <code>npx skir format</code> to format all <code>.skir</code> files in your project.
      </p>

      <h2>Continuous integration (GitHub)</h2>
      <p>
        We recommend adding <code>skirout</code> to <code>.gitignore</code> and running Skir code
        generation in your GitHub workflow. GitHub's hosted runners (Ubuntu, Windows, and macOS)
        come with Node.js and <code>npx</code> pre-installed, so you only need to add one step:
      </p>
      <CodeBlock language="yaml">{`- name: Run Skir codegen
  run: npx skir gen`}</CodeBlock>
      <p>
        If you have a formatting check step, it may fail on Skir-generated code. You can either run
        the formatting check before Skir codegen, or configure your formatter to skip{' '}
        <code>skirout</code> directories.
      </p>
      <p>Consider adding these optional steps for stricter validation:</p>
      <CodeBlock language="yaml">{`- name: Run Skir format checker
  run: npx skir format --ci

- name: Ensure Skir snapshot up-to-date
  run: npx skir snapshot --ci`}</CodeBlock>
      <p>
        The first step ensures <code>.skir</code> files are properly formatted. The second step
        verifies that you ran <code>npx skir snapshot</code> before committing. See the{' '}
        <a href="/docs/schema-evolution">Schema evolution & compatibility</a> guide for more
        information about the snapshot command.
      </p>

      <h2>IDE support</h2>
      <p>
        The official{' '}
        <a
          href="https://marketplace.visualstudio.com/items?itemName=TylerFibonacci.skir-language"
          target="_blank"
          rel="noopener noreferrer"
          className="underline decoration-muted-foreground/50 hover:text-foreground transition-colors"
        >
          VS Code extension
        </a>{' '}
        for Skir provides syntax highlighting, auto-formatting, validation, jump-to-definition, and
        other language features.
      </p>

      <div className="not-prose my-8 pt-[2px] w-[460px] max-w-full mx-auto">
        <HoverVideo src="/auto-format.mp4" />
      </div>

      <p>
        Not using VS Code? Use the{' '}
        <a
          href="https://github.com/gepheum/skir-language-server"
          target="_blank"
          rel="noopener noreferrer"
          className="underline decoration-muted-foreground/50 hover:text-foreground transition-colors"
        >
          Skir Language Server
        </a>
        .
      </p>

      <NextPageLink title="Language reference" href="/docs/language-reference" />
    </Prose>
  )
}
