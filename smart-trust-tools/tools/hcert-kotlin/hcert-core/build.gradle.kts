// The HCERT library: implements :hcert-api with the Kotlin standard library
// and the platform only (JDK on JVM and Android, node:crypto and node:zlib on
// Node). No third-party runtime dependency. [STT-GEN-004, STT-SEC-002]
plugins {
    kotlin("multiplatform")
    // Line and branch coverage of the JVM tests. Gradle ships the plugin; the
    // agent jars are pinned in gradle/verification-metadata.xml.
    jacoco
}

kotlin {
    jvm {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }
    js(IR) {
        nodejs()
        useEsModules()
        binaries.library()
        generateTypeScriptDefinitions()
    }

    sourceSets {
        commonMain.dependencies {
            api(project(":hcert-api"))
        }
        jvmTest.dependencies {
            implementation(kotlin("test-junit"))
        }
    }
}

tasks.withType<Test>().configureEach {
    // The conformance vectors and the test PKI live at the repository root.
    systemProperty("repo.root", rootProject.projectDir.parentFile.parentFile.absolutePath)
}

jacoco {
    toolVersion = "0.8.13" // released 2025-04; Gradle 8.14's default
}

// Coverage of commonMain and jvmMain by the JVM tests, as HTML and XML in
// build/reports/jacoco/jvmTestCoverage/. Run after :hcert-core:jvmTest.
val jvmTestCoverage by tasks.registering(JacocoReport::class) {
    dependsOn("jvmTest")
    executionData(layout.buildDirectory.file("jacoco/jvmTest.exec"))
    classDirectories.setFrom(layout.buildDirectory.dir("classes/kotlin/jvm/main"))
    sourceDirectories.setFrom(files("src/commonMain/kotlin", "src/jvmMain/kotlin"))
    reports {
        xml.required.set(true)
        html.required.set(true)
    }
}

// The coverage floor (STT-TST-010, test plan hcert-library-conformance): the build fails
// if a change lowers line or branch coverage below it. Raise it as tests are
// added; never lower it to pass. Verifies STT-TST-010/kotlin-floor.
val jvmTestCoverageCheck by tasks.registering(JacocoCoverageVerification::class) {
    dependsOn(jvmTestCoverage)
    executionData(layout.buildDirectory.file("jacoco/jvmTest.exec"))
    classDirectories.setFrom(layout.buildDirectory.dir("classes/kotlin/jvm/main"))
    sourceDirectories.setFrom(files("src/commonMain/kotlin", "src/jvmMain/kotlin"))
    violationRules {
        rule {
            limit { counter = "LINE"; minimum = "0.90".toBigDecimal() }
            limit { counter = "BRANCH"; minimum = "0.70".toBigDecimal() }
        }
    }
}
