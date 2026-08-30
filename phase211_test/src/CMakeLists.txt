cmake_minimum_required(VERSION 3.22)

project(flutter_jni_phase211 C)

message(STATUS "=== PHASE 211 CMAKE TOOLCHAIN TEST ===")
message(STATUS "CMAKE_VERSION=${CMAKE_VERSION}")
message(STATUS "CMAKE_HOST_SYSTEM_NAME=${CMAKE_HOST_SYSTEM_NAME}")
message(STATUS "CMAKE_HOST_SYSTEM_PROCESSOR=${CMAKE_HOST_SYSTEM_PROCESSOR}")
message(STATUS "CMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}")
message(STATUS "CMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "ANDROID_ABI=${ANDROID_ABI}")
message(STATUS "ANDROID_NDK=${ANDROID_NDK}")
message(STATUS "CMAKE_ANDROID_NDK=${CMAKE_ANDROID_NDK}")
message(STATUS "CMAKE_C_COMPILER=${CMAKE_C_COMPILER}")
message(STATUS "CMAKE_C_COMPILER_ID=${CMAKE_C_COMPILER_ID}")

add_executable(flutter_jni_phase211 main.c)

target_compile_options(
    flutter_jni_phase211
    PRIVATE
    -O2
    -fdata-sections
    -ffunction-sections
)

target_link_options(
    flutter_jni_phase211
    PRIVATE
    -nostdlib
    -nostartfiles
    -Wl,-e,main
)
