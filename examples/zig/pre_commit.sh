#!/bin/bash

set -e

npx skir format
npx skir gen
zig fmt src/
zig build
zig build run
