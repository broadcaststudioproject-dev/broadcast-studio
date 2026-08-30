#include <jni.h>
#include <android/log.h>

JNIEXPORT jint JNICALL
JNI_OnLoad(JavaVM *vm, void *reserved)
{
    __android_log_print(
        ANDROID_LOG_INFO,
        "Phase245",
        "ARM64 native test loaded"
    );

    return JNI_VERSION_1_6;
}
