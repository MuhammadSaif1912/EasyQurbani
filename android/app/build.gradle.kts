plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.easy_qurbani"
    compileSdk = 35
    ndkVersion = "29.0.13113456"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.easy_qurbani"
        minSdk = 23 // Use minSdk instead of minSdkVersion for consistency with newer Android DSL
        targetSdk = 34 // Explicitly set targetSdk for now; adjust if using flutter.targetSdkVersion
        versionCode = 1 // Explicitly set versionCode; adjust if using flutter.versionCode
        versionName = "1.0" // Explicitly set versionName; adjust if using flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Apply Google services plugin using Kotlin Script syntax
apply(plugin = "com.google.gms.google-services")