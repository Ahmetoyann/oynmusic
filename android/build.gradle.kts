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

subprojects {
    project.pluginManager.withPlugin("com.android.library") {
        // En yetkili müdahale: Tüm eklentilerin ayarları okunduktan sonra Java 17'yi zorla
        project.extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension>("androidComponents") {
            finalizeDsl { ext ->
                ext.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
                ext.compileOptions.targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }

    val applyNamespace: (Project) -> Unit = { proj ->
        if (proj.hasProperty("android")) {
            proj.extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                if (namespace == null) {
                    namespace = proj.group.toString()
                }
            }
        }

        proj.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }

    if (project.state.executed) {
        applyNamespace(project)
    } else {
        project.afterEvaluate { applyNamespace(project) }
    }
}
