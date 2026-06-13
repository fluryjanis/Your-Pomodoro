import java.util.Properties
import java.io.FileInputStream

// Load the properties from your safe, isolated home folder
val userHome = System.getProperty("user.home")
val keystorePropertiesFile = file("$userHome/android-Keys/key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.fluryjanis.remind_me"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        // Change from getByName to create so Kotlin DSL builds the container slot
        create("release") {
            val alias = keystoreProperties.getProperty("keyAlias")
            val keyPass = keystoreProperties.getProperty("keyPassword")
            val storePass = keystoreProperties.getProperty("storePassword")
            val storePath = keystoreProperties.getProperty("storeFile")

            if (alias != null && storePath != null) {
                keyAlias = alias
                keyPassword = keyPass
                storePassword = storePass
                
                val keystoreFile = file(storePath)
                if (keystoreFile.exists()) {
                    storeFile = keystoreFile
                    println("✨ SUCCESS: Verified keystore exists at ${keystoreFile.absolutePath}")
                } else {
                    // This will prevent silent failures if your key.properties path has a typo
                    throw GradleException("SIGNING ERROR: Keystore file NOT FOUND at: ${keystoreFile.absolutePath}\nPlease check your storeFile path format.")
                }
            }
        }
    }

    defaultConfig {
        applicationId = "com.fluryjanis.remind_me"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true 
            isShrinkResources = true 
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}