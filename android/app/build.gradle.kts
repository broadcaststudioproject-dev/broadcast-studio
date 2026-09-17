plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-plugin-loader")
}

android {
    namespace = "com.example.pocket_pcr_studio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "com.example.pocket_pcr_studio"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

configurations.all {
    resolutionStrategy.eachDependency {
        if (requested.group == "androidx.exifinterface" && requested.name == "exifinterface") {
            useVersion("1.3.6")
        }
        if (requested.group == "androidx.annotation" && requested.name == "annotation") {
            useVersion("1.3.0")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("io.github.pedroSG94.RootEncoder:rtmp:2.3.0")
    implementation("androidx.multidex:multidex:2.0.1")
}

