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

  console.log(`Done. Please edit: ${rewritePathForRendering(skirYmlPath)}`);
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

# Directory containing .skir files
srcDir: skir-src

# Uncomment and configure the generators for your target language(s).
generators:
  # # --------------------------------------------------------------------------
  # # C++ code generator
  # # Home: https://github.com/gepheum/skir-cc-gen
  # # To install runtime dependencies, follow instructions in repository README
  # # --------------------------------------------------------------------------
  # - mod: skir-cc-gen
  #   outDir: ./skirout
  #   config:
  #     # Set to true if you use GoogleTest
  #     writeGoogleTestHeaders: false

  # # --------------------------------------------------------------------------
  # # Dart code generator
  # # Home: https://github.com/gepheum/skir-dart-gen
  # # To install runtime dependencies: dart pub add skir_client
  # # --------------------------------------------------------------------------
  # - mod: skir-dart-gen
  #   outDir: ./skirout
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
  #   # outDir: ./src/main/java/skirout/my/project
  #   # config:
  #   #   packagePrefix: "my.project."

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
  #   # outDir: ./src/main/kotlin/skirout/my/project
  #   # config:
  #   #   packagePrefix: "my.project."

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
  #   #   packagePrefix: "my.project."

  # # --------------------------------------------------------------------------
  # # TypeScript/JavaScript code generator
  # # Home: https://github.com/gepheum/skir-typescript-gen
  # # To install runtime dependencies: npm i skir-client
  # # --------------------------------------------------------------------------
  # - mod: skir-typescript-gen
  #   outDir: ./src/skirout
  #   config:
  #     # Use ".js" for ES modules, "" for CommonJS
  #     importPathExtension: ".js"
`;

const HELLO_WORLD_SKIR_CONTENT = `/// A point in 2D space.
struct Point {
  /// x-coordinate
  x: int32;
  /// y-coordinate
  y: int32;
}
`;
