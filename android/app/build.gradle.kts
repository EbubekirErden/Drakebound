plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}
val verificationBuild = providers.gradleProperty("drakeboundVerification").orNull == "true"
android {
    namespace = "com.drakebound.android.draft"
    compileSdk = 37
    defaultConfig {
        applicationId = if (verificationBuild) "com.drakebound.android.draft.verification" else "com.drakebound.android.draft"
        minSdk = 26
        targetSdk = 37
        versionCode = 1
        versionName = "0.1-draft"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildTypes { release { isMinifyEnabled = true; isShrinkResources = true; proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt")) } }
}
dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.09.00"))
    implementation("androidx.activity:activity-compose:1.12.4")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.10.0")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation(platform("androidx.compose:compose-bom:2026.09.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    androidTestImplementation("androidx.test:runner:1.7.0")
    // API 37 removed InputManager.getInstance; the test-only alpha contains AndroidX's fix.
    androidTestImplementation("androidx.test.espresso:espresso-core:3.8.0-alpha01")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
