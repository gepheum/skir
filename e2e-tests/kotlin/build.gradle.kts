import java.time.Duration

plugins {
    kotlin("jvm") version "2.0.0"
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0"
}

group = "org.example"
version = "1.0-SNAPSHOT"

kotlin {
    compilerOptions {
        // Removed unsupported flag
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("com.squareup.okio:okio:3.6.0")
    implementation("build.skir:skir-client:1.0.16")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.5.1")
    testImplementation(kotlin("test"))
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
    testImplementation("com.google.truth:truth:1.1.5")
}

val coldSerializerTests =
    mapOf(
        "coldSerializerAccess" to "serializer",
        "coldDescriptorAccess" to "descriptor",
        "coldEnumAccess" to "enum",
        "coldToStringAccess" to "string",
        "coldConcurrentAccess" to "concurrent",
        "coldFieldAccess" to "field",
        "coldRecordAccess" to "record",
        "coldValueAccess" to "value",
        "coldValueConcurrentAccess" to "valueConcurrent",
    ).map { (taskName, scenario) ->
        tasks.register<JavaExec>(taskName) {
            dependsOn(tasks.testClasses)
            classpath = sourceSets.test.get().runtimeClasspath
            mainClass.set("ColdSerializerInitialization")
            args(scenario)
            timeout.set(Duration.ofSeconds(20))
        }
    }

tasks.test {
    dependsOn(coldSerializerTests)
    useJUnitPlatform()
}
