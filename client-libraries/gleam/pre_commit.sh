#!/bin/bash

set -e

gleam format --check src test
gleam build
gleam test
gleam docs build
