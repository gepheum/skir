#!/bin/bash

set -e

find Sources -name "*.swift" -not -path "*/skirout/*" | xargs xcrun swift-format format --in-place

npx skir format
npx skir gen
swift build
swift run Snippets
