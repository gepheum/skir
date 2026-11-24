#!/bin/bash

set -e

npx skir format
npx skir gen
cargo fmt
cargo clippy -- -D warnings
cargo build
cargo run --bin snippets
