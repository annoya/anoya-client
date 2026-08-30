plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "org.annoya.vpn_client"
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
        applicationId = "org.annoya.vpn_client"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        // The engine AAR carries arm64-v8a and x86_64 only, and the build
        // script pins Flutter to the same list — but a native-assets
        // dependency still drops a lone 32-bit stub in, which is enough for a
        // 32-bit phone to accept the install and then crash. No ABI claimed
        // by the APK may be less complete than the engine's list.
        jniLibs { excludes += "lib/armeabi-v7a/**" }
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

dependencies {
    // The mihomo engine, bound by gomobile — see native/mihomocore/build-aar.sh.
    implementation(files("libs/mihomocore.aar"))
}
