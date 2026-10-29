plugins {
    groovy
}

val groovyVersion = providers.gradleProperty("groovyVersion").get()

repositories {
    mavenCentral()
    if (groovyVersion.endsWith("-SNAPSHOT")) {
        mavenLocal()
    }
}

dependencies {
    implementation(project(":lib"))
    implementation("org.apache.groovy:groovy:$groovyVersion")
}

tasks.withType<GroovyCompile>().configureEach {
    options.isIncremental = true
}
