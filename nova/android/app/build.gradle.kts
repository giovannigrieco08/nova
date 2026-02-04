import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services plugin for Firebase (must be last)
    id("com.google.gms.google-services")
}

// Load upload keystore properties for release signing
// This file should NOT be committed to version control
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.galileimoro.nova"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.galileimoro.nova"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Signing configurations for Google Play App Signing
    // The upload key is used to sign the app bundle before uploading to Google Play
    // Google Play then re-signs with the app signing key (managed by Google)
    signingConfigs {
        create("upload") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use upload signing config if key.properties exists, otherwise fall back to debug
            // For production release: Create key.properties with upload keystore details
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("upload")
            } else {
                // Fall back to debug for development builds only
                signingConfigs.getByName("debug")
            }
            // Enable R8 code shrinking and resource shrinking for smaller APK
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Rename APK to nova-{variant}.apk
    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            output.outputFileName = "nova-${variant.buildType.name}.apk"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for flutter_local_notifications coreLibraryDesugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
