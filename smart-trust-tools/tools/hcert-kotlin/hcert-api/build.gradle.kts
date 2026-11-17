// API skeleton generated from api/wit by tools/wit2kotlin/wit2kotlin.py: declarations
// only. Implementations live in separate modules that depend on this one.
plugins {
    kotlin("multiplatform")
}

kotlin {

    // JVM (Java 11+). Android consumes this pure-Kotlin artifact directly;
    // an androidTarget() is added with the first Android-specific module
    // (Android Keystore signer).
    jvm {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }

    // Node.js via Kotlin/JS IR [STT-GEN-004].
    js(IR) {
        nodejs()
        binaries.library()
        generateTypeScriptDefinitions()
    }
}
