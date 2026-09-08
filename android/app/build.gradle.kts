import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is configured via android/key.properties (gitignored):
//   storeFile=/absolute/path/to/checkfuchs-release.jks
//   storePassword=...
//   keyAlias=...
//   keyPassword=...
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "ch.fuchsnest.checkfuchs"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time — needs core-library
        // desugaring on Android.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "ch.fuchsnest.checkfuchs"
        // Fuchsbau baseline: API 26 (adaptive icons).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // No R8 code shrinking (same call as knabberfuchs): the savings
            // are negligible for a Flutter app, and the first store build
            // crashed at startup because R8 stripped the constructor of
            // WorkManager's Room database (`WorkDatabase_Impl.<init>`) that
            // the background refresh needs. Re-enable only with full keep
            // rules for androidx.work + Room and a release-APK smoke test.
            isMinifyEnabled = false
            isShrinkResources = false
            // Use the real release key when android/key.properties exists.
            // Otherwise fall back to debug signing so `flutter run --release`
            // still works on machines without the keystore — such builds must
            // never ship (a debug-signed install can't be upgraded in place
            // by the release key).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
