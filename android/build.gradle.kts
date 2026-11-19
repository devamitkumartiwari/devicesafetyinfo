// Built-in Kotlin (AGP 9+): the Android Gradle Plugin comes from the consuming app, and Kotlin
// is compiled by AGP itself, so this module declares no buildscript classpath and applies no KGP.
plugins {
    id("com.android.library")
}

android {
    namespace = "com.devamitkumartiwari.device_safety_info"
    compileSdk = 37

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // TEMPORARY (removed in the build-hooks step): the C checks are still built with CMake.
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.18.1+"
        }
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all { it.useJUnitPlatform() }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Opt-in Play Integrity: compiled against but NOT shipped to consuming apps. Apps that request
    // Play Integrity tokens add implementation("com.google.android.play:integrity:<ver>")
    // themselves; without it the integrity API reports "unsupported" instead of crashing.
    compileOnly("com.google.android.play:integrity:1.6.0")
    testImplementation("org.jetbrains.kotlin:kotlin-test")
}
