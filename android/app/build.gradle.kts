plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "org.anoya.vpn"
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
        applicationId = "org.anoya.vpn"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures { aidl = true }

    signingConfigs {
        val keystore = System.getenv("ANDROID_KEYSTORE_PATH").orEmpty()
        if (keystore.isNotEmpty()) {
            create("release") {
                val storePass = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                storeFile = file(keystore)
                storePassword = storePass
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")?.ifEmpty { null } ?: storePass
            }
        }
    }

    buildTypes {
        release {
            // Without a keystore in the environment, local release builds stay debug-signed.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(files("libs/mihomocore.aar"))
}
