#!/bin/bash

set -e

find Sources Tests -name "*.swift" | xargs xcrun swift-format format --in-place

swift build
swift test
