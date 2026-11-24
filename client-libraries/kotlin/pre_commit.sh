#!/bin/bash

set -e

./gradlew ktlintFormat
./gradlew test
