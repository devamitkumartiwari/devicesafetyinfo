// Built-in Kotlin (AGP 9+): the Android Gradle Plugin comes from the consuming app, and Kotlin
// is compiled by AGP itself, so this module declares no buildscript classpath and applies no KGP.
// The native checks (src/dsi.c) are built by the Dart build hook (hook/build.dart), not here.
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
    // Pigeon's generated host APIs use coroutines for @async methods.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    testImplementation("org.jetbrains.kotlin:kotlin-test")
}
