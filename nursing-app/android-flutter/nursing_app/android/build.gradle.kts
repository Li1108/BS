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

val rootDrive = rootProject.projectDir.toPath().root

subprojects {
    val projectDrive = project.projectDir.toPath().root
    if (projectDrive == rootDrive) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    buildscript {
        repositories {
            google()
            mavenCentral()
        }
        configurations.matching { it.name == "classpath" }.configureEach {
            resolutionStrategy.force("com.android.tools.build:gradle:8.11.1")
        }
    }
}

fun Any.tryInvokeInt(methodName: String, value: Int): Boolean {
    val m =
        javaClass.methods.firstOrNull {
            it.name == methodName && it.parameterTypes.size == 1 && (it.parameterTypes[0] == Int::class.javaPrimitiveType || it.parameterTypes[0] == Int::class.javaObjectType)
        } ?: return false
    m.invoke(this, value)
    return true
}

fun Any.tryInvokeAny(methodName: String, value: Any): Boolean {
    val m =
        javaClass.methods.firstOrNull {
            it.name == methodName && it.parameterTypes.size == 1 && it.parameterTypes[0].isAssignableFrom(value.javaClass)
        } ?: return false
    m.invoke(this, value)
    return true
}

fun Project.configureAndroidCompat(isApplication: Boolean) {
    val androidExt = extensions.findByName("android") ?: return

    val namespaceGetter =
        androidExt.javaClass.methods.firstOrNull {
            it.name == "getNamespace" && it.parameterTypes.isEmpty()
        }
    val currentNamespace = namespaceGetter?.invoke(androidExt) as? String
    if (!isApplication && currentNamespace.isNullOrBlank()) {
        val normalizedName = project.name.replace(Regex("[^A-Za-z0-9_]"), "_")
        androidExt.tryInvokeAny("setNamespace", "com.nursing.$normalizedName")
    }

    androidExt.tryInvokeInt("setCompileSdk", 34) ||
        androidExt.tryInvokeInt("setCompileSdkVersion", 34) ||
        androidExt.tryInvokeInt("compileSdkVersion", 34)

    val defaultConfig =
        androidExt.javaClass.methods.firstOrNull { it.name == "getDefaultConfig" && it.parameterTypes.isEmpty() }?.invoke(androidExt)
    if (defaultConfig != null) {
        defaultConfig.tryInvokeInt("setMinSdk", 23) ||
            defaultConfig.tryInvokeInt("setMinSdkVersion", 23) ||
            defaultConfig.tryInvokeInt("minSdkVersion", 23)
        if (isApplication) {
            defaultConfig.tryInvokeInt("setTargetSdk", 34) ||
                defaultConfig.tryInvokeInt("setTargetSdkVersion", 34) ||
                defaultConfig.tryInvokeInt("targetSdkVersion", 34)
        }
    }

    val compileOptions =
        androidExt.javaClass.methods.firstOrNull { it.name == "getCompileOptions" && it.parameterTypes.isEmpty() }?.invoke(androidExt)
    if (compileOptions != null) {
        compileOptions.tryInvokeAny("setSourceCompatibility", JavaVersion.VERSION_17)
        compileOptions.tryInvokeAny("setTargetCompatibility", JavaVersion.VERSION_17)
    }
}

gradle.beforeProject {
    try {
        plugins.withId("com.android.library") {
            project.configureAndroidCompat(isApplication = false)
        }
        plugins.withId("com.android.application") {
            project.configureAndroidCompat(isApplication = true)
        }

        if (name == "amap_flutter_location") {
            try {
                val pluginManifest = project.file("src/main/AndroidManifest.xml")
                if (pluginManifest.exists()) {
                    val original = pluginManifest.readText()
                    val sanitized = original.replace(Regex("\\s+package=\"[^\"]*\""), "")
                    if (sanitized != original) {
                        pluginManifest.writeText(sanitized)
                    }
                }
            } catch (e: Exception) {
                logger.warn("Failed to sanitize amap_flutter_location manifest: ${e.message}")
            }
            afterEvaluate {
                configureAndroidCompat(isApplication = false)
            }
        }
    } catch (e: Exception) {
        logger.warn("Project configuration error for ${project.name}: ${e.message}")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
