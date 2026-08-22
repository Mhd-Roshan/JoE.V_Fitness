import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import com.android.build.api.variant.LibraryAndroidComponentsExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// -------------------------------------------------------------
// ULTIMATE FIX: 
// Bypasses KTS generic strictness by explicitly grabbing the Library class
// -------------------------------------------------------------
subprojects {
    pluginManager.withPlugin("com.android.library") {
        // Explicitly type the components to satisfy Kotlin DSL
        val components = extensions.getByType(LibraryAndroidComponentsExtension::class.java)
        
        components.finalizeDsl { ext ->
            ext.compileSdk = 36
            ext.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
            ext.compileOptions.targetCompatibility = JavaVersion.VERSION_17
        }
    }
    
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}