plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // 🟢 1. Google Services Plugin Added
    id("com.google.gms.google-services")
}

android {
    // 🟢 2. Package Name Updated
    namespace = "com.hyper.swiftchat"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // 🟢 3. Application ID Updated
        applicationId = "com.hyper.swiftchat"
        
        // 🟢 4. Min SDK 23 set kiya (Firebase requirement)
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 🟢 5. MultiDex ON kiya
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// 🟢 6. MultiDex Library Added
dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}