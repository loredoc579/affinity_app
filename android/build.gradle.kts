plugins {
    // Dichiariamo le versioni, ma NON le applichiamo a livello di project
    id("com.android.application")      version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false
    // Nota: NON dichiariamo qui il loader né il plugin Flutter
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
