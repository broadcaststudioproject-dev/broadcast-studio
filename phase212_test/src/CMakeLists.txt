cmake_minimum_required(VERSION 3.22)

project(flutter_jni_phase212 C)

message(STATUS "======================================")
message(STATUS " PHASE 212 CMAKE CONFIGURATION")
message(STATUS "======================================")

message(STATUS "CMAKE_VERSION=${CMAKE_VERSION}")
message(STATUS "CMAKE_HOST_SYSTEM_NAME=${CMAKE_HOST_SYSTEM_NAME}")
message(STATUS "CMAKE_HOST_SYSTEM_PROCESSOR=${CMAKE_HOST_SYSTEM_PROCESSOR}")

message(STATUS "CMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}")
message(STATUS "CMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}")

message(STATUS "ANDROID_ABI=${ANDROID_ABI}")
message(STATUS "ANDROID_PLATFORM=${ANDROID_PLATFORM}")

message(STATUS "ANDROID_NDK=${ANDROID_NDK}")
message(STATUS "CMAKE_ANDROID_NDK=${CMAKE_ANDROID_NDK}")

message(STATUS "CMAKE_C_COMPILER=${CMAKE_C_COMPILER}")
message(STATUS "CMAKE_C_COMPILER_ID=${CMAKE_C_COMPILER_ID}")
message(STATUS "CMAKE_C_COMPILER_TARGET=${CMAKE_C_COMPILER_TARGET}")

message(STATUS "LIBUNWIND=/data/data/com.termux/files/usr/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/lib/i386-unknown-linux-gnu/libunwind.a")

add_executable(flutter_jni_phase212 main.c)

target_compile_options(
    flutter_jni_phase212
    PRIVATE
    -O2
    -fdata-sections
    -ffunction-sections
)

target_link_options(
    flutter_jni_phase212
    PRIVATE
    -nostdlib
    -nostartfiles
    -Wl,-e,main
)

# IMPORTANT:
# Use absolute libunwind archive path.
# Do NOT use -lunwind here.

target_link_libraries(
    flutter_jni_phase212
    PRIVATE
    "/data/data/com.termux/files/usr/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/lib/i386-unknown-linux-gnu/libunwind.a"
)

