import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Credenciales de firma del proyecto. Viven en android/key.properties, que
// NO esta en git: hay que pedirselo al equipo junto con el .jks.
//
// Importa que la firma sea siempre la misma, compile quien compile: Google
// identifica la app por "paquete + huella del certificado". Con la clave de
// depuracion, cada PC generaba una firma distinta y el login con Google
// fallaba con ApiException: 10 en todas menos en la que se registro.
val propiedadesFirma = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) {
        archivo.inputStream().use { load(it) }
    }
}
val hayFirmaPropia = propiedadesFirma.getProperty("storeFile") != null

android {
    namespace = "com.example.ika_travel_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.16248370" // versión instalada localmente

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.ika_travel_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hayFirmaPropia) {
            create("release") {
                storeFile = rootProject.file(propiedadesFirma.getProperty("storeFile"))
                storePassword = propiedadesFirma.getProperty("storePassword")
                keyAlias = propiedadesFirma.getProperty("keyAlias")
                keyPassword = propiedadesFirma.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Sin key.properties se firma con la clave de depuracion, para que
            // `flutter run --release` siga funcionando sin configurar nada. Ese
            // APK NO sirve para repartir: el login con Google fallaria.
            signingConfig = if (hayFirmaPropia) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
