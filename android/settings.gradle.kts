import java.net.InetSocketAddress
import java.net.Socket

fun isSystemOnline(): Boolean {
    return try {
        val socket = Socket()
        socket.connect(InetSocketAddress("8.8.8.8", 53), 800)
        socket.close()
        true
    } catch (e: Exception) {
        false
    }
}

if (!isSystemOnline()) {
    gradle.startParameter.isOffline = true
}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
