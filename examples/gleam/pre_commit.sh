#!/bin/bash

set -e

gleam format src/*.gleam
npx skir format
npx skir gen
gleam build
gleam run -m snippets
