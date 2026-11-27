#!/bin/bash
set -e

cd "$(dirname "$0")"
dune build
dune runtest
