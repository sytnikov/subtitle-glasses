import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// meta_wearables_dat_flutter consumes Meta's official Android DAT SDK from
// GitHub Packages Maven. A GitHub personal access token with the
// `read:packages` scope is required: set GITHUB_TOKEN in the environment
// or add `github_token=<token>` to android/local.properties.
val metaWearablesLocalProperties =
    Properties().apply {
        val localPropertiesFile = rootProject.file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { load(it) }
        }
    }

repositories {
    maven {
        url = uri("https://maven.pkg.github.com/facebook/meta-wearables-dat-android")
        credentials {
            username = "" // not needed
            password = System.getenv("GITHUB_TOKEN")
                ?: metaWearablesLocalProperties.getProperty("github_token")
                ?: ""
        }
    }
}

android {
    namespace = "com.aleksei.finnishsubtitles.finnish_subtitles"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.aleksei.finnishsubtitles.finnish_subtitles"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // meta_wearables_dat_flutter requires minSdk 31 (Android 12).
        minSdk = 31
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
