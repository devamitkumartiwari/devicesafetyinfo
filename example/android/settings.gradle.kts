pluginManagement {
    val flutterSdkPath: String = run {
        // pluginManagement has its own compilation scope; read the file
        // line-by-line to avoid needing java.util.Properties here.
        file("local.properties")
            .readLines()
            .firstOrNull { it.startsWith("flutter.sdk=") }
            ?.removePrefix("flutter.sdk=")
            ?: error("flutter.sdk not set in local.properties")
    }
    settings.extra["flutterSdkPath"] = flutterSdkPath

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
