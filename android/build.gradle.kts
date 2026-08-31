allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = '../build'
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}
subprojects {
    project.evaluationDependsOn(':app')
    
    // ప్రాజెక్ట్ లోని అన్ని ప్యాకేజీలను 34 వెర్షన్ కి అప్‌గ్రేడ్ చేసే మ్యాజిక్ కోడ్
    afterEvaluate { project ->
        if (project.hasProperty('android')) {
            project.android {
                compileSdkVersion 34
            }
        }
    }
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
