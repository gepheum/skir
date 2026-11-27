#!/bin/bash

set -e

npx skir format
npx skir gen
dune build
dune exec ./snippets.exe
