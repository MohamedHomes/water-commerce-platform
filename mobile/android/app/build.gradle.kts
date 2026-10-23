plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseEnvironment = mapOf(
    "AQUAFLOW_APPLICATION_ID" to System.getenv("AQUAFLOW_APPLICATION_ID"),
    "AQUAFLOW_KEYSTORE_FILE" to System.getenv("AQUAFLOW_KEYSTORE_FILE"),
    "AQUAFLOW_KEYSTORE_PASSWORD" to System.getenv("AQUAFLOW_KEYSTORE_PASSWORD"),
    "AQUAFLOW_KEY_ALIAS" to System.getenv("AQUAFLOW_KEY_ALIAS"),
    "AQUAFLOW_KEY_PASSWORD" to System.getenv("AQUAFLOW_KEY_PASSWORD"),
)
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val releaseApplicationId = releaseEnvironment["AQUAFLOW_APPLICATION_ID"]
val hasReleaseSigning = releaseEnvironment
    .filterKeys { it != "AQUAFLOW_APPLICATION_ID" }
    .values.all { !it.isNullOrBlank() }

if (releaseBuildRequested) {
    if (releaseApplicationId.isNullOrBlank() || releaseApplicationId.startsWith("com.example.")) {
        throw GradleException("Configure a unique AQUAFLOW_APPLICATION_ID before a release build")
    }
    if (!hasReleaseSigning) {
        throw GradleException("Configure all AQUAFLOW keystore variables before a release build")
    }
}

android {
    namespace = "com.example.aquaflow_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = releaseApplicationId ?: "com.example.aquaflow_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (hasReleaseSigning) {
        signingConfigs {
            create("release") {
                storeFile = file(releaseEnvironment["AQUAFLOW_KEYSTORE_FILE"]!!)
                storePassword = releaseEnvironment["AQUAFLOW_KEYSTORE_PASSWORD"]
                keyAlias = releaseEnvironment["AQUAFLOW_KEY_ALIAS"]
                keyPassword = releaseEnvironment["AQUAFLOW_KEY_PASSWORD"]
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
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
