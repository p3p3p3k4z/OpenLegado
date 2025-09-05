import java.util.Properties
import java.io.FileInputStream
import java.io.File

val dotenv = Properties()
val dotenvFile = File(rootDir.parentFile, ".env")
if (dotenvFile.exists()) {
    dotenv.load(FileInputStream(dotenvFile))
}

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
    namespace = "com.example.legado_app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Se agregó esta línea para habilitar el desugaring de la biblioteca
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.legado_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.

        // ESTA ES LA LÍNEA MODIFICADA:
        minSdk = 23

        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = dotenv["GOOGLE_MAPS_API_KEY"]?.toString() ?: ""
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
    // Se agregó esta línea para el soporte de "core library desugaring"
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
