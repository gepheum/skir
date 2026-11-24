#!/bin/bash

set -euo pipefail

echo "Running MoonBit pre-commit checks..."

moon fmt
moon check --target native .
moon test --target native .
