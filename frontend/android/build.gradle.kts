buildscript {
    // ここでKotlinのバージョンを定義します。API 34対応のため 1.9.0 以上を推奨。
    val kotlin_version by extra("2.2.20")
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle Plugin (API 34対応には 8.1.0 以上が必要)
        classpath("com.android.tools.build:gradle:8.1.2")
        // Kotlin Gradle Plugin
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
    }
}

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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}