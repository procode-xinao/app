import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/** 解码 Flutter 传入的 `-Pdart-defines=`（与 Dart 侧 encodeDartDefines 一致：逗号分隔的 base64(UTF-8) 的「KEY=VALUE」）。 */
fun decodeFlutterDartDefines(raw: String?): Map<String, String> {
    if (raw.isNullOrBlank()) return emptyMap()
    val result = mutableMapOf<String, String>()
    for (part in raw.split(",")) {
        val trimmed = part.trim()
        if (trimmed.isEmpty()) continue
        try {
            val decoded = String(Base64.getDecoder().decode(trimmed), Charsets.UTF_8)
            val eq = decoded.indexOf('=')
            if (eq > 0) {
                result[decoded.substring(0, eq)] = decoded.substring(eq + 1)
            }
        } catch (_: IllegalArgumentException) {
            // 非法 base64，跳过
        }
    }
    return result
}

android {
    namespace = "com.procode.app"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.procode.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 主屏幕应用名：优先 --dart-define=APP_DISPLAY_NAME=xxx，其次 android/gradle.properties 的 flutter.appDisplayName
        val fromDartDefines =
            decodeFlutterDartDefines(project.findProperty("dart-defines")?.toString())["APP_DISPLAY_NAME"]
        val fromGradle = project.findProperty("flutter.appDisplayName")?.toString()
        val appDisplayName = (fromDartDefines ?: fromGradle ?: "我的应用")
        resValue("string", "app_name", appDisplayName)

        // 极光推送：建议通过 --dart-define 或 gradle.properties 注入，避免把 key 写死在仓库里
        val jpushAppKey =
            decodeFlutterDartDefines(project.findProperty("dart-defines")?.toString())["JPUSH_APP_KEY"]
                ?: project.findProperty("jpush.appKey")?.toString()
                ?: ""
        val jpushChannel =
            decodeFlutterDartDefines(project.findProperty("dart-defines")?.toString())["JPUSH_CHANNEL"]
                ?: project.findProperty("jpush.channel")?.toString()
                ?: "default"
        manifestPlaceholders["JPUSH_APPKEY"] = jpushAppKey
        manifestPlaceholders["JPUSH_CHANNEL"] = jpushChannel
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
