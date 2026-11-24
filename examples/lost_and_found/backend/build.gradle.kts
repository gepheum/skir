plugins {
    kotlin("jvm") version "1.9.22"
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0"
    application
}

group = "com.intergalactic.lostfound"
version = "1.0.0"

repositories {
    mavenCentral()
}

dependencies {
    // Skir runtime
    implementation("build.skir:skir-client:latest.release")

    // Ktor server
    val ktorVersion = "2.3.7"
    implementation("io.ktor:ktor-server-core:$ktorVersion")
    implementation("io.ktor:ktor-server-netty:$ktorVersion")
    implementation("io.ktor:ktor-server-cors:$ktorVersion")

    // Logging
    implementation("ch.qos.logback:logback-classic:1.4.14")

    // Kotlin coroutines - match Ktor's coroutines version
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
}

application {
    mainClass.set("com.intergalactic.lostfound.MainKt")
}

kotlin {
    jvmToolchain(17)
}
