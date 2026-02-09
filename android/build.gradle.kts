// 🟢 1. Plugins Block (Sabse Top par hona chahiye)
plugins {
    // Android Application Plugin (Version match karna chahiye aapke setup se)
    id("com.android.application") version "8.11.1" apply false
    
    // Kotlin Plugin
    id("org.jetbrains.kotlin.android") version "2.2.20 apply false

    // 🟢 YE HAI WO LINE JO MISSING THI (Crash Fix)
    id("com.google.gms.google-services") version "4.4.2" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}