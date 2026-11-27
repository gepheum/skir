#!/bin/bash
set -e

validate_lang() {
  case "$1" in
    cc|csharp|dart|fsharp|gleam|go|java|kotlin|moonbit|ocaml|python|ruby|rust|scala|swift|typescript|zig) ;;
    *)
      echo "Unknown language: $1" >&2
      echo "Supported languages: cc, csharp, dart, fsharp, gleam, go, java, kotlin, moonbit, ocaml, python, ruby, rust, scala, swift, typescript, zig" >&2
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

cd "$ROOT_DIR"
npm run build
cd "$SCRIPT_DIR"

# TypeScript E2E tests
if should_run "typescript"; then
  echo "=== Running TypeScript E2E tests ==="
  node "$SKIR_CLI" format --ci -r typescript
  node "$SKIR_CLI" gen -r typescript
  npx tsc -b typescript
  node --import tsx "$ROOT_DIR/node_modules/mocha/bin/mocha.js" "typescript/src/**/*.test.ts"
fi

# Python E2E tests
if should_run "python"; then
  echo "=== Running Python E2E tests ==="
  node "$SKIR_CLI" format --ci -r python
  node "$SKIR_CLI" gen -r python
  cd python
  if [ -d "test-env" ]; then
    test-env/bin/pip install -r requirements.txt
    test-env/bin/python3 -m unittest discover -s tests -p "*.py"
  else
    python3 -m venv test-env
    test-env/bin/pip install -r requirements.txt
    test-env/bin/python3 -m unittest discover -s tests -p "*.py"
  fi
  cd "$SCRIPT_DIR"
fi

# Ruby E2E tests
if should_run "ruby"; then
  echo "=== Running Ruby E2E tests ==="
  if [ -d "/opt/homebrew/opt/ruby@3.4/bin" ]; then
    export PATH="/opt/homebrew/opt/ruby@3.4/bin:/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"
  fi
  node "$SKIR_CLI" format --ci -r ruby
  node "$SKIR_CLI" gen -r ruby
  cd ruby
  srb tc
  ruby -I../../client-libraries/ruby/lib -I. test/test_goldens.rb
  ruby -I../../client-libraries/ruby/lib -I. test/test_skirout.rb
  cd "$SCRIPT_DIR"
fi

# Rust E2E tests
if should_run "rust"; then
  echo "=== Running Rust E2E tests ==="
  node "$SKIR_CLI" format --ci -r rust
  node "$SKIR_CLI" gen -r rust
  cd rust
  cargo test
  cd "$SCRIPT_DIR"
fi

# Go E2E tests
if should_run "go"; then
  echo "=== Running Go E2E tests ==="
  node "$SKIR_CLI" format --ci -r go
  node "$SKIR_CLI" gen -r go
  cd go
  go mod tidy
  go test ./...
  cd "$SCRIPT_DIR"
fi

# Kotlin E2E tests
if should_run "kotlin"; then
  echo "=== Running Kotlin E2E tests ==="
  node "$SKIR_CLI" format --ci -r kotlin
  node "$SKIR_CLI" gen -r kotlin
  cd kotlin
  ./gradlew test ktlintCheck
  cd "$SCRIPT_DIR"
fi

# Java E2E tests
if should_run "java"; then
  echo "=== Running Java E2E tests ==="
  node "$SKIR_CLI" format --ci -r java
  node "$SKIR_CLI" gen -r java
  cd java
  ./gradlew build spotlessCheck
  cd "$SCRIPT_DIR"
fi

# Scala E2E tests
if should_run "scala"; then
  echo "=== Running Scala E2E tests ==="
  node "$SKIR_CLI" format --ci -r scala
  node "$SKIR_CLI" gen -r scala
  cd scala
  ./gradlew test
  cd "$SCRIPT_DIR"
fi

# C# E2E tests
if should_run "csharp"; then
  echo "=== Running C# E2E tests ==="
  node "$SKIR_CLI" format --ci -r csharp
  node "$SKIR_CLI" gen -r csharp
  cd csharp
  dotnet build CsharpE2eTest.csproj -warnaserror
  dotnet test SkirClientTest/SkirClientTest.csproj -p:TreatWarningsAsErrors=true
  cd "$SCRIPT_DIR"
fi

# F# E2E tests
if should_run "fsharp"; then
  echo "=== Running F# E2E tests ==="
  node "$SKIR_CLI" format --ci -r fsharp
  node "$SKIR_CLI" gen -r fsharp
  cd fsharp
  dotnet run --project FsharpE2eTest.fsproj
  cd "$SCRIPT_DIR"
fi

# Dart E2E tests
if should_run "dart"; then
  echo "=== Running Dart E2E tests ==="
  node "$SKIR_CLI" format --ci -r dart
  node "$SKIR_CLI" gen -r dart
  cd dart
  dart pub get
  dart analyze --fatal-infos
  dart test
  cd "$SCRIPT_DIR"
fi

# Gleam E2E tests
if should_run "gleam"; then
  echo "=== Running Gleam E2E tests ==="
  node "$SKIR_CLI" format --ci -r gleam
  node "$SKIR_CLI" gen -r gleam
  cd gleam
  gleam build
  gleam test
  cd "$SCRIPT_DIR"
fi

# Swift E2E tests
if should_run "swift"; then
  echo "=== Running Swift E2E tests ==="
  node "$SKIR_CLI" format --ci -r swift
  node "$SKIR_CLI" gen -r swift
  cd swift
  swift test
  cd "$SCRIPT_DIR"
fi

# Zig E2E tests
if should_run "zig"; then
  echo "=== Running Zig E2E tests ==="
  node "$SKIR_CLI" format --ci -r zig
  node "$SKIR_CLI" gen -r zig
  cd zig
  zig build test
  cd "$SCRIPT_DIR"
fi

# MoonBit E2E tests
if should_run "moonbit"; then
  echo "=== Running MoonBit E2E tests ==="
  node "$SKIR_CLI" format --ci -r moonbit
  cd moonbit
  rm -rf skirout
  node "$SKIR_CLI" gen
  for p in $(find skirout -name moon.pkg -exec dirname {} +); do
    moon check "./$p" || exit 1
  done
  moon test ./goldens-tests
  cd "$SCRIPT_DIR"
fi

# OCaml E2E tests
if should_run "ocaml"; then
  echo "=== Running OCaml E2E tests ==="
  node "$SKIR_CLI" format --ci -r ocaml
  rm -rf ocaml/skirout
  node "$SKIR_CLI" gen -r ocaml
  cd ocaml
  dune runtest
  cd "$SCRIPT_DIR"
fi

# C++ E2E tests
if should_run "cc"; then
  echo "=== Running C++ E2E tests ==="
  node "$SKIR_CLI" format --ci -r cc
  node "$SKIR_CLI" gen -r cc
  cd cc
  cmake -B build -DCMAKE_BUILD_TYPE=Debug
  cmake --build build
  ctest --test-dir build --output-on-failure
  cd "$SCRIPT_DIR"
fi
