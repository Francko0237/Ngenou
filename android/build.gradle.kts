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
    val configureProject = Action<Project> {
        if (name == "flutter_local_notifications") {
            // Delete original ScheduledNotificationReceiver.class right after Java compilation is done.
            // This prevents duplicate class conflicts with our custom shadow implementation in :app, 
            // without breaking compile-time references in the plugin.
            tasks.withType<JavaCompile>().configureEach {
                doLast {
                    val classFile = File(destinationDirectory.get().asFile, "com/dexterous/flutterlocalnotifications/ScheduledNotificationReceiver.class")
                    if (classFile.exists()) {
                        logger.quiet("=== Excluded duplicate class: deleting ScheduledNotificationReceiver.class from plugin build folder ===")
                        classFile.delete()
                    }
                }
            }
        }
    }

    if (state.executed) {
        configureProject.execute(this)
    } else {
        afterEvaluate {
            configureProject.execute(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
