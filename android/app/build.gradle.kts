import org.gradle.api.JavaVersion

plugins {
    id("com.android.application")
    id("kotlin-android")
    // El plugin de Flutter debe ir después de Android y Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.portones_mym"

    // Usar los valores que define Flutter automáticamente
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // ─────────────────────────────────────────────
    // COMPATIBILIDAD JAVA / KOTLIN
    // Esto evita el error de "Inconsistent JVM Target"
    // ─────────────────────────────────────────────
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.portones_mym"

        // Usar configuraciones que Flutter ya calcula
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Por ahora se firma con debug para poder generar APK sin keystore
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Para evitar conflictos con versiones de Java modernas
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // Requerido para que funcionen notificaciones y APIs modernas en Android
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
