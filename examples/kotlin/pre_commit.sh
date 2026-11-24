#!/bin/bash

set -e

./gradlew ktlintFormat
npx skir gen
./gradlew build
./gradlew run
