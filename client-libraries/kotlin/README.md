[![Maven Central](https://img.shields.io/maven-central/v/build.skir/skir-client)](https://central.sonatype.com/artifact/build.skir/skir-client)
[![build](https://github.com/gepheum/skir-kotlin-client/workflows/Build/badge.svg)](https://github.com/gepheum/skir-kotlin-client/actions)

# Skir Kotlin Client

Library imported from Kotlin and Java code generated from skir files.

## Installation

### Gradle (Kotlin DSL)

```kotlin
dependencies {
    implementation("build.skir:skir-client:latest.release")
}
```

### Gradle (Groovy DSL)

```groovy
dependencies {
    implementation 'build.skir:skir-client:latest.release'
}
```

### Maven

```xml
<dependency>
    <groupId>build.skir</groupId>
    <artifactId>skir-kotlin-client</artifactId>
    <version>1.0.3<!-- Pick the latest version --></version>
</dependency>
```

## Java Compatibility

This library can be used in Java projects as well as Kotlin projects. The generated code and client library are fully compatible with Java.

## See Also

*   [skir](https://github.com/gepheum/skir): home of the skir compiler
*   [skir-kotlin-gen](https://github.com/gepheum/skir-kotlin-gen): skir to Kotlin code generator
*   [skir-kotlin-example](https://github.com/gepheum/skir-kotlin-example): example showing how to use skir's Kotlin code generator in a project
