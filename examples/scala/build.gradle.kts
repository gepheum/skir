plugins {
    scala
    application
}

group = "com.example"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.scala-lang:scala3-library_3:3.3.4")
    implementation("build.skir:skir-client:latest.release")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-jdk8:1.7.3")
    implementation("com.squareup.okio:okio:3.6.0")
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

application {
    mainClass.set(
        if (project.hasProperty("mainClass")) {
            project.property("mainClass") as String
        } else {
            "examples.Snippets"
        },
    )
}
