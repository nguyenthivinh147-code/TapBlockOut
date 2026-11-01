plugins {
    id("com.android.library") version "8.6.1"
    id("org.jetbrains.kotlin.android") version "2.1.21"
}

android {
    namespace = "com.tapblockout.platform"
    compileSdk = 36
    buildToolsVersion = "36.0.0"

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
        // Firebase 35 co metadata Kotlin 2.4, compiler 2.1.21 (cung ban voi Godot) chi can doc API Java.
        freeCompilerArgs += "-Xskip-metadata-version-check"
    }
}

dependencies {
    // Godot do ban chay cung cap luc chay, chi dung de bien dich.
    compileOnly("org.godotengine:godot:4.7.2.stable")

    // Quang cao va dong y GDPR (UMP do chinh luong consent cua MAX can).
    implementation("com.applovin:applovin-sdk:13.7.0")
    implementation("com.google.android.ump:user-messaging-platform:4.0.0")

    // Firebase: BoM chot phien ban cho ca ba thu vien.
    implementation(platform("com.google.firebase:firebase-bom:35.1.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-config")
    implementation("com.google.firebase:firebase-crashlytics")

    // Attribution.
    implementation("com.adjust.sdk:adjust-android:5.8.1")
    implementation("com.google.android.gms:play-services-ads-identifier:18.2.0")
    implementation("com.android.installreferrer:installreferrer:2.2")

    // Danh gia trong app va Saved Games.
    implementation("com.google.android.play:review:2.0.2")
    implementation("com.google.android.gms:play-services-games-v2:22.1.0")
}
