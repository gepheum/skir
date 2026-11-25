import com.vanniktech.maven.publish.SonatypeHost

plugins {
    kotlin("jvm") version "2.0.0"
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0"
    id("com.vanniktech.maven.publish") version "0.28.0"
    id("org.jetbrains.dokka") version "1.9.10"
}

group = "build.skir"
version = "1.0.17"

kotlin {
    jvmToolchain(17)
    compilerOptions {
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("com.squareup.okio:okio:3.6.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.5.1")
    testImplementation(kotlin("test"))
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
    testImplementation("com.google.truth:truth:1.1.5")
}

tasks.test {
    useJUnitPlatform()
}

// Configure Dokka for HTML documentation
tasks.dokkaHtml.configure {
    outputDirectory.set(layout.buildDirectory.dir("dokka"))
}

// Generate Javadoc-style documentation
tasks.dokkaJavadoc.configure {
    outputDirectory.set(layout.buildDirectory.dir("docs/javadoc"))
}

// Convenient alias for generating documentation
tasks.register("generateDocs") {
    description = "Generates all documentation (HTML and Javadoc)"
    group = "documentation"
    dependsOn(tasks.dokkaHtml, tasks.dokkaJavadoc)
}

// From https://proandroiddev.com/publishing-kotlin-multiplatform-libraries-with-sonatype-central-b40f7cc6866e
mavenPublishing {
    // Define coordinates for the published artifact
    coordinates(
        groupId = "build.skir",
        artifactId = "skir-client",
        version = "1.0.17",
    )

    // Configure POM metadata for the published artifact
    pom {
        name.set("Skir Kotlin Client")
        description.set("Serializable Kotlin data types generated from .skir files")
        inceptionYear.set("2025")
        url.set("https://github.com/gepheum/skir")

        licenses {
            license {
                name.set("MIT")
                url.set("https://opensource.org/licenses/MIT")
            }
        }

        // Specify developers information
        developers {
            developer {
                id.set("gepheum")
                name.set("Tyler Fibonacci")
                email.set("gepheum@gmail.com")
            }
        }

        // Specify SCM information
        scm {
            url.set("https://github.com/gepheum/skir")
        }
    }

    // Configure publishing to Maven Central
    publishToMavenCentral(SonatypeHost.CENTRAL_PORTAL)

    // Enable GPG signing for all publications
    signAllPublications()
}
