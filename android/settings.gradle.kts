// android/settings.gradle.kts

// 1. Definisco le versioni AGP e Kotlin in variabili
val agpVersion: String by settings
val kotlinVersion: String by settings

pluginManagement {
    // 2. Recupero il flutter.sdk da local.properties
    val flutterSdkPath: String = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        properties.getProperty("flutter.sdk")
            ?: error("flutter.sdk non è impostato in local.properties")
    }

    // 3. Includo il build script di flutter_tools
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    plugins {
        id("dev.flutter.flutter-plugin-loader") version "1.0.0"
        id("com.android.application")         version "8.7.0"  apply false
        id("org.jetbrains.kotlin.android")    version "1.8.22" apply false
        id("com.google.gms.google-services")  version "4.3.15"    apply false
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "affinity_app"
include(":app")
