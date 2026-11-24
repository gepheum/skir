#!/bin/bash

set -euo pipefail

echo "Running MoonBit pre-commit checks..."

moon fmt
moon check
moon test
