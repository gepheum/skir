#!/bin/bash

set -e

zig fmt --check src/skir_client.zig build.zig
zig build test -Doptimize=Debug
zig build test -Doptimize=ReleaseSafe
