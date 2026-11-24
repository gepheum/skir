#!/bin/bash
#
# pre_commit.sh - Run pre-commit formatting, linters, builds, and tests.
#
# Usage:
#   ./pre_commit.sh                 # Full check: formats, lints, builds, and tests in all languages
#   ./pre_commit.sh --fast          # Fast check: skips polyglot formatting & E2E tests across all languages
#   ./pre_commit.sh --lang <name>   # Format & test a single language only (e.g. --lang rust)
#
# Supported languages for --lang:
#   cc, csharp, dart, gleam, go, java, kotlin, moonbit, python, rust, swift, typescript, zig
#

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
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--fast] [--lang <language>]" >&2
      exit 1
      ;;
  esac
done

npm run lint:fix
npm run lint
npm run format
npm run build
npm test

ARGS=()
if [ "$FAST" = true ]; then
  ARGS+=("--fast")
fi
if [ -n "$LANG_TARGET" ]; then
  ARGS+=("--lang" "$LANG_TARGET")
fi

./e2e-tests/format-all.sh "${ARGS[@]}"
./e2e-tests/test.sh "${ARGS[@]}"
