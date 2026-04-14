import org.gradle.api.JavaVersion
import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    // ✅ Firebase / Google Services plugin
    id("com.google.gms.google-services") version "4.3.15" apply false
}

/**
 * Configures all projects in the build to use Google's and Maven Central repositories.
 */
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

/**
 *  Redirects the root project's build directory from "android/build" to "build".
 *  This is to align with Flutter's default output directory.
 */
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

/**
 * Configures all subprojects.
 */
subprojects {
    // Redirects each subproject's build directory to be inside the new root build directory.
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Ensures that the ':app' project is evaluated before any other subproject.
    // This is useful if other projects depend on configurations or tasks defined in ':app'.
    project.evaluationDependsOn(":app")

    // ✅ Java tasks a 17 (incluye plugins como shared_preferences_android)
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }

    // ✅ Kotlin a JVM 17 para todos los módulos/plugins
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

/**
 * Registers a custom "clean" task at the root level.
 * This task deletes the custom root build directory.
 */
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
