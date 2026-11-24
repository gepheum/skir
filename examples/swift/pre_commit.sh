#!/bin/bash

set -e

find Sources Tests -name "*.swift" | xargs xcrun swift-format format --in-place

npx skir format
npx skir gen
swift build
swift run Snippets
