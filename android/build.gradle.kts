buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.6.0")
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

subprojects {
    val project = this
    
    fun applyAndroidFixes(proj: Project) {
        val android = proj.extensions.findByName("android")
        if (android != null) {
            try {
                // Fix for isar_flutter_libs namespace if missing
                try {
                    val getNamespace = android.javaClass.getMethod("getNamespace")
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    if (getNamespace.invoke(android) == null) {
                        setNamespace.invoke(android, "dev.isar.isar_flutter_libs")
                    }
                } catch (e: Exception) {}

                // Force compileSdk to 36 to fix lStar error
                try {
                    val setCompileSdk = android.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType ?: Int::class.java)
                    setCompileSdk.invoke(android, 36)
                } catch (e: Exception) {
                    try {
                        val compileSdkVersion = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType ?: Int::class.java)
                        compileSdkVersion.invoke(android, 36)
                    } catch (e2: Exception) {
                    }
                }
            } catch (e: Exception) {
                println("ERROR: Failed in applyAndroidFixes for ${proj.name}: $e")
            }
        }
    }

    if (project.state.executed) {
        applyAndroidFixes(project)
    } else {
        project.afterEvaluate {
            applyAndroidFixes(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
