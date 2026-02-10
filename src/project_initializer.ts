import * as FileSystem from "fs";
import * as Paths from "path";
import { rewritePathForRendering } from "./io.js";

export function initializeProject(rootDir: string): void {
  const skirYmlPath = Paths.join(rootDir, "skir.yml");

  // Check if skir.yml already exists
  if (FileSystem.existsSync(skirYmlPath)) {
    console.log(
      "A skir.yml file already exists in this directory. Skipping project initialization.",
    );
    return;
  }

  // Create skir.yml file
  FileSystem.writeFileSync(skirYmlPath, SKIR_YML_CONTENT, "utf-8");

  // Check if skir-src directory exists
  const skirSrcDir = Paths.join(rootDir, "skir-src");
  if (!FileSystem.existsSync(skirSrcDir)) {
    // Create skir-src directory
    FileSystem.mkdirSync(skirSrcDir, { recursive: true });

    // Create hello_world.skir file
    const helloWorldPath = Paths.join(skirSrcDir, "hello_world.skir");
    FileSystem.writeFileSync(helloWorldPath, HELLO_WORLD_SKIR_CONTENT, "utf-8");
  }

  // Update .gitignore if it exists
  const gitIgnorePath = Paths.join(rootDir, ".gitignore");
  if (FileSystem.existsSync(gitIgnorePath)) {
    const content = FileSystem.readFileSync(gitIgnorePath, "utf-8");
    const lines = content.split(/\r?\n/);
    const toAdd: string[] = [];

    for (const dirName of ["skirout", "skir-external"]) {
      const hasDir = lines.some(
        (line) => line.trim().replace(/\/$/, "") === dirName,
      );
      if (!hasDir) {
        toAdd.push(`${dirName}/`);
      }
    }

    if (toAdd.length > 0) {
      const append = `\n${toAdd.join("\n")}\n`;
      FileSystem.appendFileSync(gitIgnorePath, append, "utf-8");
    }
  }

  console.log(`Done. Please edit: ${rewritePathForRendering(skirYmlPath)}`);
  console.log("To generate code, run: npx skir gen [--watch]");
}

const SKIR_YML_CONTENT = `# Configuration file for Skir code generator
#
# Documentation: https://skir.build/
#
# Cheat sheet:
#   npx skir gen          Generate code from .skir files
#   npx skir gen --watch  Watch for changes and regenerate automatically
#   npx skir format       Format all .skir files
#   npx skir snapshot     Take a snapshot of the source directory, verify no
#                         breaking changes since last snapshot

# Uncomment and configure the generators for your target language(s).
generators:
  # --------------------------------------------------------------------------
  # C++ code generator
  # Home: https://github.com/gepheum/skir-cc-gen
  # To install runtime dependencies, follow instructions in repository README
  # --------------------------------------------------------------------------
  - mod: skir-cc-gen
    outDir: ./skirout
    config:
      # Set to true if you use GoogleTest
      writeGoogleTestHeaders: false

  # # --------------------------------------------------------------------------
  # # Dart code generator
  # # Home: https://github.com/gepheum/skir-dart-gen
  # # To install runtime dependencies: dart pub add skir_client
  # # --------------------------------------------------------------------------
  # - mod: skir-dart-gen
  #   outDir: ./lib/skirout
  #   config: {}

  # # --------------------------------------------------------------------------
  # # Java code generator
  # # Home: https://github.com/gepheum/skir-java-gen
  # # Add the following line to your build.gradle dependencies:
  # #    implementation("build.skir:skir-client:latest.release")
  # # --------------------------------------------------------------------------
  # - mod: skir-java-gen
  #   outDir: ./src/main/java/skirout
  #   config: {}
  #   # Alternatively:
  #   # outDir: ./src/main/java/my/project/skirout
  #   # config:
  #   #   packagePrefix: my.project.

  # # --------------------------------------------------------------------------
  # # Kotlin code generator
  # # Home: https://github.com/gepheum/skir-kotlin-gen
  # # Add the following line to your build.gradle dependencies:
  # #   implementation("build.skir:skir-client:latest.release")
  # # --------------------------------------------------------------------------
  # - mod: skir-kotlin-gen
  #   outDir: ./src/main/kotlin/skirout
  #   config: {}
  #   # Alternatively:
  #   # outDir: ./src/main/kotlin/my/project/skirout
  #   # config:
  #   #   packagePrefix: my.project.

  # # --------------------------------------------------------------------------
  # # Python code generator
  # # Home: https://github.com/gepheum/skir-python-gen
  # # To install runtime dependencies: pip install skir-client
  # # --------------------------------------------------------------------------
  # - mod: skir-python-gen
  #   outDir: ./skirout
  #   config: {}
  #   # Alternatively:
  #   # outDir: ./my/project/skirout
  #   # config:
  #   #   packagePrefix: my.project.

  # # --------------------------------------------------------------------------
  # # TypeScript/JavaScript code generator
  # # Home: https://github.com/gepheum/skir-typescript-gen
  # # To install runtime dependencies: npm i skir-client
  # # --------------------------------------------------------------------------
  # - mod: skir-typescript-gen
  #   outDir: ./skirout
  #   config:
  #     # Use ".js" for ES modules, "" for CommonJS
  #     importPathExtension: ".js"

# # --------------------------------------------------------------------------
# # External Skir dependencies hosted on GitHub
# # To use an external repository, specify the GitHub repository identifier
# # in the format "@owner/repository-name" and the release tag version.
# # --------------------------------------------------------------------------
# dependencies:
#   # Add a dependency to:
#   #   https://github.com/gepheum/skir-fantasy-game-example/tree/v1.0.0
#   "@gepheum/skir-fantasy-game-example": v1.0.0

# # --------------------------------------------------------------------------
# # GitHub Personal Access Token (required for private dependencies)
# # Set this to the name of an environment variable containing your GitHub
# # token. The token is used to authenticate when downloading dependencies.
# # --------------------------------------------------------------------------
# githubTokenEnvVar: GITHUB_TOKEN
`;

const HELLO_WORLD_SKIR_CONTENT = `/// A point in 2D space.
struct Point {
  /// x-coordinate
  x: int32;
  /// y-coordinate
  y: int32;
}
`;
