plugins {

    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace    = "com.example.affinity_app"
    compileSdk   = 33
    ndkVersion   = "26.3.11579264"

    defaultConfig {
        applicationId = "com.example.affinity_app"
        minSdk        = 21
        targetSdk     = 33
        versionCode   = 1
        versionName   = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            isMinifyEnabled   = true      // <— abilita la minificazione
            isShrinkResources = true      // resource shrinking OK
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
