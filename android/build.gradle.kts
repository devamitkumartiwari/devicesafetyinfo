plugins {
    id("com.android.library")
}

group = "com.devamitkumartiwari.device_safety_info"
version = "1.0-SNAPSHOT"

android {
    namespace = "com.devamitkumartiwari.device_safety_info"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
        getByName("test").java.srcDirs("src/test/kotlin")
    }

    defaultConfig {
        minSdk = 24
        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64"))
        }
        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++17"
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.18.1+"
        }
    }

    testOptions {
        unitTests.all { test ->
            test.useJUnitPlatform()
            test.outputs.upToDateWhen { false }
            test.testLogging {
                events("passed", "skipped", "failed", "standardOut", "standardError")
                showStandardStreams = true
            }
        }
    }
}

dependencies {
    testImplementation("org.jetbrains.kotlin:kotlin-test")
}

// KGP is applied transitively by Flutter's dev.flutter.flutter-gradle-plugin.
// Using the tasks API lets KTS resolve the type from the build classpath without
// this sub-project applying id("org.jetbrains.kotlin.android") directly.
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
