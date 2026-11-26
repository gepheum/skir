import java.time.Duration

plugins {
    scala
}

group = "org.example"
version = "1.0-SNAPSHOT"

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.scala-lang:scala3-library_3:3.3.4")
    implementation("com.squareup.okio:okio:3.6.0")
    implementation("build.skir:skir-client:1.0.16")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.5.1")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
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
