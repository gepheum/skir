#!/bin/bash

set -e

# Format C++ files (excluding build/, skirout/, and hidden directories)
find . -type f \( -name '*.cc' -o -name '*.h' \) \
  -not -path './build/*' \
  -not -path './skirout/*' \
  -not -path './.*/*' \
  | xargs -r clang-format -i

# Generate skir code
npx skir gen

# Build and test
if [ ! -d "build" ]; then
  mkdir build
fi
cd build
cmake ..
cmake --build .
ctest --output-on-failure

./example
