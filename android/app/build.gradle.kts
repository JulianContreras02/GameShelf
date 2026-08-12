import java.util.Properties

plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.kotlin.android)
  alias(libs.plugins.kotlin.compose)
  alias(libs.plugins.kotlin.serialization)
  alias(libs.plugins.ksp)
}

/**
 * Lee los secretos del mismo sitio que la version de iOS.
 *
 * El puerto reutiliza `Config/Secrets.xcconfig` a proposito: el archivo ya
 * existe en el repo, ya esta ignorado por git y su formato (`CLAVE = valor`
 * con comentarios `//`) se parsea sin problema. Asi quien tenga las dos
 * versiones no mantiene dos archivos de claves.
 *
 * Si no esta, se cae a `local.properties`. Si tampoco, los valores quedan
 * vacios: igual que en iOS, la app **compila** y avisa dentro de que claves
 * faltan, en vez de romper el build.
 */
fun secretos(): Map<String, String> {
  val valores = mutableMapOf<String, String>()

  val local = rootProject.file("local.properties")
  if (local.exists()) {
    val props = Properties().apply { local.inputStream().use { load(it) } }
    props.forEach { (k, v) -> valores[k.toString()] = v.toString() }
  }

  val xcconfig = rootProject.file("../Config/Secrets.xcconfig")
  if (xcconfig.exists()) {
    xcconfig.readLines().forEach { linea ->
      val limpia = linea.substringBefore("//").trim()
      if (limpia.contains("=")) {
        val clave = limpia.substringBefore("=").trim()
        val valor = limpia.substringAfter("=").trim()
        if (clave.isNotEmpty()) valores[clave] = valor
      }
    }
  }

  return valores
}

android {
  namespace = "com.gameshelf"
  compileSdk = 35

  defaultConfig {
    applicationId = "com.gameshelf"
    minSdk = 26
    targetSdk = 35
    versionCode = 1
    versionName = "1.0"

    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

    val claves = secretos()
    listOf("STEAM_API_KEY", "STEAM_ID", "ITAD_API_KEY").forEach { clave ->
      buildConfigField("String", clave, "\"${claves[clave].orEmpty()}\"")
    }
  }

  buildTypes {
    release {
      isMinifyEnabled = false
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    }
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  kotlinOptions {
    jvmTarget = "17"
  }

  buildFeatures {
    compose = true
    buildConfig = true
  }

  testOptions {
    unitTests {
      isIncludeAndroidResources = true
      isReturnDefaultValues = true
    }
  }

  packaging {
    resources {
      excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
  }
}

ksp {
  arg("room.schemaLocation", "$projectDir/schemas")
}

dependencies {
  implementation(libs.androidx.core.ktx)
  implementation(libs.androidx.lifecycle.runtime.ktx)
  implementation(libs.androidx.lifecycle.viewmodel.compose)
  implementation(libs.androidx.activity.compose)

  implementation(platform(libs.androidx.compose.bom))
  implementation(libs.androidx.ui)
  implementation(libs.androidx.ui.graphics)
  implementation(libs.androidx.ui.tooling.preview)
  implementation(libs.androidx.material3)
  implementation(libs.androidx.material.icons.extended)
  implementation(libs.androidx.navigation.compose)
  debugImplementation(libs.androidx.ui.tooling)

  implementation(libs.androidx.room.runtime)
  implementation(libs.androidx.room.ktx)
  ksp(libs.androidx.room.compiler)

  implementation(libs.androidx.security.crypto)

  implementation(libs.okhttp)
  implementation(libs.kotlinx.serialization.json)
  implementation(libs.coil.compose)

  testImplementation(libs.junit)
  testImplementation(libs.robolectric)
  testImplementation(libs.kotlinx.coroutines.test)
  testImplementation(libs.okhttp.mockwebserver)

  androidTestImplementation(libs.androidx.junit)
  androidTestImplementation(libs.androidx.espresso.core)
  androidTestImplementation(platform(libs.androidx.compose.bom))
}
