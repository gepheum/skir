#!/bin/bash

set -e

gleam format
npx skir format
npx skir gen
gleam build
gleam run -m snippets
