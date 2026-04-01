import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val releaseSigningRequiredKeys = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)

fun hasValidReleaseSigningConfig(): Boolean {
    if (!keystorePropertiesFile.exists()) {
        return false
    }
    return releaseSigningRequiredKeys.all { key ->
        val value = keystoreProperties.getProperty(key)
        !value.isNullOrBlank()
    }
}

val hasReleaseSigningConfig = hasValidReleaseSigningConfig()

android {
    namespace = "com.bitsend.app.bitsend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.bitsend.app.bitsend"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigningConfig) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            if (!hasReleaseSigningConfig) {
                throw GradleException(
                    "Release signing is not configured. Add android/key.properties with storeFile, storePassword, keyAlias, and keyPassword.",
                )
            }
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
