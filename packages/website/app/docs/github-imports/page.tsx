import { NextPageLink } from '@/components/next-page-link'
import { CodeBlock, Note, Prose } from '@/components/prose'

export const metadata = {
  title: 'GitHub imports - Skir Documentation',
  description:
    'Import types from other GitHub repositories to share common data structures across projects.',
}

export default function GitHubImportsPage() {
  return (
    <Prose>
      <h1>GitHub imports</h1>
      <p>
        Skir allows you to import and use types defined in other Skir projects. This is primarily
        useful for sharing common data structures across multiple repositories. External
        dependencies are regular GitHub repositories that contain Skir definitions.
      </p>

      <h2>Configuring dependencies</h2>
      <p>
        To add a dependency, open your <code>skir.yml</code> file and add an entry to the{' '}
        <code>dependencies</code> section. The key is the GitHub repository identifier (
        <code>owner/repo</code> prefixed with <code>@</code>), and the value is the Git tag or
        release version you want to use.
      </p>
      <CodeBlock language="yaml" filename="skir.yml">{`dependencies:
  # https://github.com/gepheum/skir-fantasy-game-example/tree/v1.0.0
  "@gepheum/skir-fantasy-game-example": v1.0.0

  "@my-org/user-service-skir": v3.5.0`}</CodeBlock>
      <p>
        When you run <code>npx skir gen</code>, Skir will automatically fetch these dependencies and
        cache them in the <code>skir-external/</code> directory.
      </p>
      <Note type="info">
        <p>
          The <code>skir-external/</code> directory should be added to your <code>.gitignore</code>.
        </p>
      </Note>

      <h3>Transitive dependencies</h3>
      <p>
        Dependencies are transitive: if A depends on B, and B depends on C, then A implicitly
        depends on C. Skir will automatically download all transitive dependencies.
      </p>
      <p>
        To ensure consistency, Skir strictly forbids version conflicts. If two dependencies (direct
        or transitive) require different versions of the same package, the compiler will report an
        error. You must resolve this conflict by ensuring all usages align on a single version.
      </p>

      <h2>Importing types</h2>
      <p>
        Once a dependency is configured, you can import types from it using the <code>import</code>{' '}
        statement in your <code>.skir</code> files. The import path is the full path to the file
        within the dependency, prefixed with the package identifier.
      </p>
      <CodeBlock language="skir">{`import { Quest } from "@gepheum/skir-fantasy-game-example/fantasy_game.skir";

struct QuestCollection {
  collection_name: string;
  quests: [Quest|quest_id];
}`}</CodeBlock>

      <h2>Code generation</h2>
      <p>
        For languages which allow <code>@</code> symbols in directory names (like JavaScript), the
        code generated from external dependencies is placed in{' '}
        <code>{'skirout/@{owner}/{repo}'}</code>:
      </p>
      <CodeBlock language="javascript">{`// JavaScript

import { Quest } from "../skirout/@gepheum/skir-fantasy-game-example/fantasy_game.js"`}</CodeBlock>
      <p>
        For languages which require every directory name to be a valid identifier (like Python), the
        generated code is placed in <code>{'skirout/external/{owner}/{repo}'}</code>, with dashes
        replaced by underscores:
      </p>
      <CodeBlock language="python">{`# Python

from skirout.external.gepheum.skir_fantasy_game_example import fantasy_game_skir`}</CodeBlock>

      <h2>Private repositories</h2>
      <p>
        If your dependencies are hosted in private GitHub repositories, you need to provide a GitHub
        Personal Access Token so Skir can download them.
      </p>

      <h3>1. Generate a token</h3>
      <p>
        Go to your GitHub settings and{' '}
        <a href="https://github.com/settings/tokens" target="_blank" rel="noopener noreferrer">
          generate a new Personal Access Token (Classic)
        </a>{' '}
        with the <code>repo</code> scope (for full control of private repositories) or just{' '}
        <code>read:packages</code> if applicable, though usually <code>repo</code> is needed for
        private source code access.
      </p>

      <h3>2. Set the environment variable</h3>
      <p>Set an environment variable with your token. For example:</p>
      <CodeBlock language="bash">{`export MY_GITHUB_TOKEN=ghp_...`}</CodeBlock>

      <h3>3. Configure skir.yml</h3>
      <p>
        Tell Skir which environment variable to look for in your <code>skir.yml</code>:
      </p>
      <CodeBlock language="yaml" filename="skir.yml">{`# skir.yml
githubTokenEnvVar: MY_GITHUB_TOKEN`}</CodeBlock>
      <p>
        Skir will now read the token from <code>MY_GITHUB_TOKEN</code> to authenticate requests.
      </p>

      <h3>4. Set up GitHub Actions CI</h3>
      <p>
        When running Skir in a Continuous Integration (CI) environment like GitHub Actions, you can
        use the built-in <code>{'${{ secrets.GITHUB_TOKEN }}'}</code> to access other repositories
        within the same organization, or use a repository secret if you need broader access.
      </p>
      <p>Here is an example workflow step:</p>
      <CodeBlock language="yaml">{`steps:
  - uses: actions/checkout@v3

  - name: Install dependencies and generate code
    run: npx skir gen
    env:
      # Pass the token to the environment variable configured in skir.yml
      MY_GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}`}</CodeBlock>
      <Note type="warning">
        <p>
          If the dependency is in a different private repository that the default{' '}
          <code>GITHUB_TOKEN</code> cannot access, you will need to create a Personal Access Token
          (PAT), store it as a Repository Secret (e.g., <code>PAT_TOKEN</code>), and use that
          instead.
        </p>
      </Note>

      <NextPageLink title="Best Practices" href="/docs/best-practices" />
    </Prose>
  )
}
