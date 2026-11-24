#!/bin/bash

set -e

dart format .
dart analyze
dart test
