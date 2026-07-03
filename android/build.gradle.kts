allprojects {
    repositories {
        google()
        mavenCentral()
        // Mapbox SDK downloads. Requires a secret token (sk....) with the
        // "Downloads:Read" scope, stored as MAPBOX_DOWNLOADS_TOKEN in the
        // global gradle.properties (~/.gradle/gradle.properties) so it is
        // never committed to the repo.
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                create<BasicAuthentication>("basic")
            }
            credentials {
                username = "mapbox"
                password = providers.gradleProperty("MAPBOX_DOWNLOADS_TOKEN").orNull ?: ""
            }
        }
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
// Force every Android module (including Flutter plugins like
// mapbox_maps_flutter and flutter_plugin_android_lifecycle) to compile against
// API 36, which the Mapbox SDK requires. Registered before the
// evaluationDependsOn block below so the hook is attached before any project is
// evaluated. Uses reflection so it works across Android Gradle Plugin versions
// without a compile-time dependency on its types.
subprojects {
    afterEvaluate {
        val androidExtension = extensions.findByName("android") ?: return@afterEvaluate
        runCatching {
            androidExtension.javaClass
                .getMethod("setCompileSdk", Integer::class.java)
                .invoke(androidExtension, 36)
        }.recoverCatching {
            androidExtension.javaClass
                .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                .invoke(androidExtension, 36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
