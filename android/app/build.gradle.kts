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
    sourceCompatibility = JavaVersion.VERSION_1_8
    targetCompatibility = JavaVersion.VERSION_1_8
}
kotlinOptions {
    jvmTarget = "1.8"
}

    packaging {
        resources.excludes.add("project.clj")
    }

    defaultConfig {
        applicationId = "com.example.pocket_pcr_studio"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
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
        if (requested.group == "androidx.annotation" && requested.name == "annotation-experimental") {
            useVersion("1.3.0")
        }
    }
}

flutter {
    source = "../.."
}
dependencies {
    implementation("io.github.pedroSG94.RootEncoder:rtmp:2.3.0")
}
