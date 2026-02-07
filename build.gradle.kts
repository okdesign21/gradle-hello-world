plugins {
    kotlin("jvm") version "2.3.0"
    id("application")
    id("java")
    id("idea")

    // This is used to create a GraalVM native image
    id("org.graalvm.buildtools.native") version "0.11.1"

    // This creates a fat JAR
    id("com.gradleup.shadow") version "9.3.1"
}

group = "com.ido"
version = "1.0.1"
description = "HelloWorld"

application.mainClass.set("com.ido.HelloWorld")

repositories {
    mavenCentral()
}

graalvmNative {
    binaries {
        named("main") {
            imageName.set("helloworld")
            mainClass.set("com.ido.HelloWorld")
            fallback.set(false)
            sharedLibrary.set(false)
            useFatJar.set(true)
            javaLauncher.set(
                javaToolchains.launcherFor {
                    languageVersion.set(JavaLanguageVersion.of(21))
                    vendor.set(JvmVendorSpec.matching("GraalVM Community"))
                },
            )
        }
    }
}
