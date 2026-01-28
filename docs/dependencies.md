# External dependencies

Skir allows you to import and use types defined in other Skir projects. This is primarily useful for sharing common data structures across multiple repositories. External dependencies are regular GitHub repositories that contain Skir definitions.

## Configuring dependencies

To add a dependency, open your `skir.yml` file and add an entry to the `dependencies` section. The key is the GitHub repository identifier (`owner/repo` prefixed with `@`), and the value is the Git tag or release version you want to use.

```yaml
dependencies:
  # https://github.com/gepheum/fantasy-game-skir-example/tree/v1.0.0
  "@gepheum/fantasy-game-skir-example": v1.0.0

  "@my-org/user-service-skir": v3.5.0
```

When you run `npx skir gen`, Skir will automatically fetch these dependencies and cache them in the `skir-external/` directory.

> **Note:** The `skir-external/` directory should be added to your `.gitignore`.

### Transitive dependencies

Dependencies are transitive: if A depends on B, and B depends on C, then A implicitly depends on C. Skir will automatically download all transitive dependencies.

To ensure consistency, Skir strictly forbids version conflicts. If two dependencies (direct or transitive) require different versions of the same package, the compiler will report an error. You must resolve this conflict by ensuring all usages align on a single version.

## Importing types

Once a dependency is configured, you can import types from it using the `import` statement in your `.skir` files. The import path is the full path to the file within the dependency, prefixed with the package identifier.

```d
import Quest from "@gepheum/fantasy-game-skir-example/fantasy_game.skir";

struct QuestCollection {
  collection_name: string;
  quests: [Quest|quest_id];
}
```

## Code generation

For languages which allow `@` symbols in directory names (like JavaScript), the code generated from external dependencies is placed in `skirout/@{owner}/{repo}`:

```javascript
// Javascript

import { Quest } from "../skirout/@gepheum/fantasy-game-skir-example/fantasy_game.js"
```

For languages which require every directory name to be a valid identifier (like Python), the generated code is placed in `skirout/external/{owner}/{repo}`, with dashes replaced by underscores:

```python
# Python

from skirout.external.gepheum.fantasy_game_skir_example import fantasy_game_skir
```

## Private repositories

If your dependencies are hosted in private GitHub repositories, you need to provide a GitHub Personal Access Token so Skir can download them.

### 1. Generate a token
Go to your GitHub settings and [generate a new Personal Access Token (Classic)](https://github.com/settings/tokens) with the `repo` scope (for full control of private repositories) or just `read:packages` if applicable, though usually `repo` is needed for private source code access.

### 2. Set the environment variable
Set an environment variable with your token. For example:

```bash
export MY_GITHUB_TOKEN=ghp_...
```

### 3. Configure skir.yml
Tell Skir which environment variable to look for in your `skir.yml`:

```yaml
# skir.yml
githubTokenEnvVar: MY_GITHUB_TOKEN
```

Skir will now read the token from `MY_GITHUB_TOKEN` to authenticate requests.

### 4. Set up GitHub Actions CI

When running Skir in a Continuous Integration (CI) environment like GitHub Actions, you can use the built-in `${{ secrets.GITHUB_TOKEN }}` to access other repositories within the same organization, or use a repository secret if you need broader access.

Here is an example workflow step:

```yaml
steps:
  - uses: actions/checkout@v3

  - name: Install dependencies and generate code
    run: npx skir gen
    env:
      # Pass the token to the environment variable configured in skir.yml
      MY_GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Important:** If the dependency is in a different private repository that the default `GITHUB_TOKEN` cannot access, you will need to create a Personal Access Token (PAT), store it as a Repository Secret (e.g., `PAT_TOKEN`), and use that instead:

```yaml
    env:
      MY_GITHUB_TOKEN: ${{ secrets.PAT_TOKEN }}
```
