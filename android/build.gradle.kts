// 🟢 PART 1: Build Script (Ye naya add kiya hai)
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Ye Android Gradle Plugin ka version hai (Agar purana error de toh isse change mat karna)
        classpath("com.android.tools.build:gradle:8.2.1") 
        
        // 👇 MAIN CHEEZ: Google Services Classpath
        classpath("com.google.gms:google-services:4.4.2")
    }
}

// 🟢 PART 2: Tumhara Purana Code (As it is)
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
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