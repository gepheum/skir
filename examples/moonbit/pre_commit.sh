#!/bin/bash

set -euo pipefail

echo "Running MoonBit example pre-commit checks..."

npx skir format
npx skir gen
moon fmt
moon check --target native
moon test src --target native --filter snippets
