#!/bin/bash

set -e

./gradlew spotlessApply
npx skir gen
./gradlew run
