import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play upload key: android/key.properties (gitignored, see
// key.properties.example) or USRA_UPLOAD_* environment variables for CI.
// Without either, release builds fall back to the debug key so contributors
// and CI can still build them; Play rejects those uploads. See docs/release.md.
val keyProperties =
    Properties().apply {
        val file = rootProject.file("key.properties")
        if (file.exists()) file.inputStream().use { load(it) }
    }

fun uploadKey(property: String, env: String): String? =
    keyProperties.getProperty(property) ?: System.getenv(env)?.takeIf { it.isNotBlank() }

val uploadStoreFile = uploadKey("storeFile", "USRA_UPLOAD_STORE_FILE")
val hasUploadKey = uploadStoreFile != null

android {
    namespace = "com.opsedia.usra"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications schedules with java.time on old Androids.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent once the app is on Play: never change it.
        applicationId = "com.opsedia.usra"
        // Pinned rather than following Flutter's defaults so a Flutter
        // upgrade can't move them silently. Play requires targeting API 35+
        // for new apps and updates (36 from August 2026).
        minSdk = 24
        targetSdk = 36
        // `version: x.y.z+N` in pubspec.yaml: versionName x.y.z, versionCode N.
        // Every Play upload needs a higher N.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = rootProject.file(uploadStoreFile!!)
                storePassword = uploadKey("storePassword", "USRA_UPLOAD_STORE_PASSWORD")
                keyAlias = uploadKey("keyAlias", "USRA_UPLOAD_KEY_ALIAS")
                keyPassword = uploadKey("keyPassword", "USRA_UPLOAD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // R8 (minify + resource shrinking) is turned on by the Flutter
            // plugin, which also adds proguard-rules.pro.
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "upload" else "debug")
        }
    }
}

// Warn only when a release is actually being built, not on every debug run.
if (!hasUploadKey) {
    gradle.taskGraph.whenReady {
        if (allTasks.any { it.project == project && it.name.contains("Release") }) {
            logger.warn("Usra: no upload key (android/key.properties or USRA_UPLOAD_*); signing release with the debug key.")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
