#!/bin/bash
set -e

validate_lang() {
  case "$1" in
    cc|csharp|dart|gleam|go|java|kotlin|moonbit|python|rust|swift|typescript|zig) ;;
    *)
      echo "Unknown language: $1" >&2
      echo "Supported languages: cc, csharp, dart, gleam, go, java, kotlin, moonbit, python, rust, swift, typescript, zig" >&2
      exit 1
      ;;
  esac
}

FAST=false
LANG_TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --fast)
      FAST=true
      shift
      ;;
    --lang)
      if [ -z "$2" ]; then
        echo "Error: --lang requires a language argument" >&2
        exit 1
      fi
      validate_lang "$2"
      LANG_TARGET="$2"
      shift 2
      ;;
    --lang=*)
      val="${1#--lang=}"
      validate_lang "$val"
      LANG_TARGET="$val"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

should_run() {
  [ "$FAST" != true ] && { [ -z "$LANG_TARGET" ] || [ "$LANG_TARGET" = "$1" ]; }
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKIR_CLI="$ROOT_DIR/packages/compiler/dist/compiler.js"

cd "$SCRIPT_DIR"

if should_run "typescript"; then
  echo "=== Formatting TypeScript E2E tests ==="
  node "$SKIR_CLI" format -r typescript
  npx prettier --write "typescript/src/**/*.ts"
fi

if should_run "python"; then
  echo "=== Formatting Python client & E2E tests ==="
  node "$SKIR_CLI" format -r python
  if command -v black >/dev/null 2>&1; then
    black python/tests
    (cd "$ROOT_DIR/client-libraries/python" && (command -v isort >/dev/null 2>&1 && isort . || true) && black .)
    (cd "$ROOT_DIR/client-libraries/python-sqlalchemy" && (command -v isort >/dev/null 2>&1 && isort . || true) && black .)
  fi
fi

if should_run "rust"; then
  echo "=== Formatting Rust client & E2E tests ==="
  node "$SKIR_CLI" format -r rust
  (cd rust && cargo fmt)
  (cd "$ROOT_DIR/client-libraries/rust" && cargo fmt)
fi

if should_run "go"; then
  echo "=== Formatting Go client & E2E tests ==="
  node "$SKIR_CLI" format -r go
  (cd go && gofmt -w .)
  (cd "$ROOT_DIR/client-libraries/go" && gofmt -w .)
fi

if should_run "kotlin"; then
  echo "=== Formatting Kotlin client & E2E tests ==="
  node "$SKIR_CLI" format -r kotlin
  (cd kotlin && ./gradlew ktlintFormat)
  (cd "$ROOT_DIR/client-libraries/kotlin" && ./gradlew ktlintFormat)
fi

if should_run "java"; then
  echo "=== Formatting Java E2E tests ==="
  node "$SKIR_CLI" format -r java
  (cd java && ./gradlew spotlessApply)
fi

if should_run "csharp"; then
  echo "=== Formatting C# client & E2E tests ==="
  node "$SKIR_CLI" format -r csharp
  (cd csharp && dotnet format CsharpE2eTest.csproj && dotnet format SkirClientTest/SkirClientTest.csproj)
  (cd "$ROOT_DIR/client-libraries/csharp" && dotnet format SkirClient.csproj && dotnet format SkirClientTest/SkirClientTest.csproj)
fi

if should_run "dart"; then
  echo "=== Formatting Dart client & E2E tests ==="
  node "$SKIR_CLI" format -r dart
  (cd dart && dart format .)
  (cd "$ROOT_DIR/client-libraries/dart" && dart format .)
fi

if should_run "gleam"; then
  echo "=== Formatting Gleam client & E2E tests ==="
  node "$SKIR_CLI" format -r gleam
  (cd gleam && gleam format src test)
  (cd "$ROOT_DIR/client-libraries/gleam" && gleam format src test)
fi

if should_run "swift"; then
  echo "=== Formatting Swift client & E2E tests ==="
  node "$SKIR_CLI" format -r swift
  xcrun swift-format format --in-place swift/Tests/*.swift
  find "$ROOT_DIR/client-libraries/swift/Sources" "$ROOT_DIR/client-libraries/swift/Tests" -name "*.swift" -exec xcrun swift-format format --in-place {} +
fi

if should_run "zig"; then
  echo "=== Formatting Zig client & E2E tests ==="
  node "$SKIR_CLI" format -r zig
  (cd zig && zig fmt $(find src -name '*.zig' -not -path '*/skirout/*') build.zig)
  (cd "$ROOT_DIR/client-libraries/zig" && zig fmt src/skir_client.zig build.zig)
fi

if should_run "moonbit"; then
  echo "=== Formatting MoonBit client & E2E tests ==="
  node "$SKIR_CLI" format -r moonbit
  (cd "$ROOT_DIR/client-libraries/moonbit" && moon fmt)
  (cd "$ROOT_DIR/client-libraries/moonbit-async" && moon fmt)
fi

if should_run "cc"; then
  echo "=== Formatting C++ client & E2E tests ==="
  node "$SKIR_CLI" format -r cc
  find cc -maxdepth 1 \( -name '*.cc' -o -name '*.h' \) -exec clang-format --Werror -i {} +
  find "$ROOT_DIR/client-libraries/cc" -maxdepth 1 \( -name '*.cc' -o -name '*.h' \) -exec clang-format --Werror -i {} +
fi
