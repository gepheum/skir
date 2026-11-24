#!/bin/bash
cd "$(dirname "$0")"
java -cp "build/classes/kotlin/main:build/resources/main:$(find ~/.gradle/caches/modules-2/files-2.1 -name "*.jar" | tr '\n' ':')" com.intergalactic.lostfound.MainKt
