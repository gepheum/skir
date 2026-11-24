#!/bin/bash

set -e

cargo fmt
cargo clippy -- -D warnings
cargo test
