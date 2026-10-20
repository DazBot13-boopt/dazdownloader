import java.io.File
import java.io.FileInputStream
import java.net.URI
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Pin the official Python zipapp; don't ship the library's 2025 extractor.
val pinnedYtdlpVersion = "2026.08.19"
val pinnedYtdlpSha256 = "1fa6733c37ea6fb51c99ad8fe785e7b7e5f3246c9b980230329d4fb72ed8d4d6"
// Google Play upload-key credentials. Populated by the release workflow from
// GitHub secrets; absent in local dev where we fall back to the debug cert.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

val engineResources = layout.buildDirectory.dir("generated/pinnedEngine/res")
val preparePinnedEngine by tasks.registering {
    val binary = engineResources.map { it.file("raw/daz_ytdlp") }
    inputs.property("version", pinnedYtdlpVersion)
    inputs.property("sha256", pinnedYtdlpSha256)
    outputs.file(binary)
    doLast {
        val destination = binary.get().asFile
        fun digest(file: File): String = MessageDigest.getInstance("SHA-256")
            .digest(file.readBytes()).joinToString("") { "%02x".format(it) }
        if (!destination.exists() || digest(destination) != pinnedYtdlpSha256) {
            destination.parentFile.mkdirs()
            val temporary = File.createTempFile("engine-", ".download", destination.parentFile)
            try {
                val connection = URI("https://github.com/yt-dlp/yt-dlp/releases/download/$pinnedYtdlpVersion/yt-dlp").toURL().openConnection()
                connection.connectTimeout = 15000
                connection.readTimeout = 30000
                connection.getInputStream().use { input -> temporary.outputStream().use { input.copyTo(it) } }
                check(digest(temporary) == pinnedYtdlpSha256) { "Official yt-dlp checksum mismatch" }
                Files.move(temporary.toPath(), destination.toPath(), StandardCopyOption.REPLACE_EXISTING)
            } finally { temporary.delete() }
        }
    }
}

android {
    namespace = "com.dazdownloader.dazdownloader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    // AGP 9 rejects Provider instances in the legacy SourceSet API. The task
    // dependency below still guarantees that this directory exists before
    // resources are processed.
    sourceSets.getByName("main").res.srcDir(engineResources.get().asFile)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.dazdownloader.dazdownloader"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(24, flutter.minSdkVersion)
        // Android 15 / HiOS devices can reject packages that declare the
        // Android 16 target before their vendor installer supports it.
        targetSdk = 35
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Pin the debug signing config to the user's `~/.android/debug.keystore`.
        // AGP's default debug config path depends on `user.home` as the Gradle
        // JVM sees it, which differs between dev machines and CI runners —
        // without this override, AGP silently falls back to a freshly generated
        // keystore and the resulting APK can't upgrade an install signed by
        // the real one.
        getByName("debug") {
            storeFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        create("release") {
            // Only wired when the release workflow has materialised
            // android/key.properties + the upload keystore. The buildType
            // below falls back to the debug cert when they are absent so
            // `flutter run --release` keeps working on dev machines.
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // The engine's published AAR omits its required consumer rules.
            proguardFiles("proguard-rules.pro")
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // No upload key present → keep the debug cert so dev
                // `flutter run --release` and the current debug-signed APK
                // workflow continue to produce installable builds.
                signingConfigs.getByName("debug")
            }
        }
    }

    packaging {
        jniLibs.useLegacyPackaging = true
        // These are archives intentionally packaged as native resources.
        jniLibs.keepDebugSymbols += "**/*.zip.so"
        resources.excludes += setOf("META-INF/DEPENDENCIES")
    }
}

tasks.named("preBuild").configure { dependsOn(preparePinnedEngine) }

dependencies {
    val mediaEngineVersion = "0.18.1"
    implementation("io.github.junkfood02.youtubedl-android:library:$mediaEngineVersion")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:$mediaEngineVersion")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.documentfile:documentfile:1.0.1")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
