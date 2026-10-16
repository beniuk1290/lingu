allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// NOTE: some third-party plugins (file_picker, flutter_inappwebview_android,
// flutter_local_notifications, share_plus, jni, jni_flutter, flutter_timezone)
// pin compileSdk to 34/35 while newer transitive dependencies
// (flutter_plugin_android_lifecycle) require 36 — same as the app module.
// Their android/build.gradle files are patched to compileSdk 36 in the local
// pub cache (C:\dev\pub-cache). If you re-resolve dependencies and the AAR
// metadata error comes back, re-apply compileSdk 34/35 → 36 in those files.

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
