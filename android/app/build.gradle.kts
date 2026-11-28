import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Lecture du fichier key.properties avec fallback sur variables d'environnement (CI/CD)
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

fun signingProp(key: String): String {
    // Priorité : variable d'environnement CI > key.properties local
    return System.getenv(key) ?: (keyProperties[key] as? String ?: "")
}

android {
    namespace = "com.ngenou.app"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }



    signingConfigs {
        create("release") {
            keyAlias     = signingProp("keyAlias")
            keyPassword  = signingProp("keyPassword")
            storePassword = signingProp("storePassword")
            val sf = signingProp("storeFile")
            if (sf.isNotEmpty()) storeFile = file(sf)
        }
    }

    defaultConfig {
        applicationId = "com.ngenou.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // Utilise la keystore release en debug aussi pour que
            // Google Sign-In fonctionne (le SHA-1 enregistré dans Google Cloud
            // Console est celui de ta keystore release, pas celle de debug).
            signingConfig = signingConfigs.getByName("release")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("com.google.code.gson:gson:2.10.1")
}
