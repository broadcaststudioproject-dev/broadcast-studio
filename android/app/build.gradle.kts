plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.pocket_pcr_studio"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // 🔥 RTMP ప్యాకేజీ ఫైల్ కాన్‌ఫ్లిక్ట్ రాకుండా ఇక్కడ ఎక్స్‌క్లూడ్ చేయబడింది
    packaging {
        resources.excludes.add("project.clj")
    }

    defaultConfig {
        applicationId = "com.example.pocket_pcr_studio"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
