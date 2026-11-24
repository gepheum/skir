#!/bin/bash

set -e

dart pub get
npx skir gen
dart analyze
dart run --enable-asserts bin/snippets.dart
