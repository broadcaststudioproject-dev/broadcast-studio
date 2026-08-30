set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 24)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER /data/data/com.termux/files/usr/bin/clang)
set(CMAKE_CXX_COMPILER /data/data/com.termux/files/usr/bin/clang++)

set(CMAKE_C_COMPILER_TARGET aarch64-linux-android24)
set(CMAKE_CXX_COMPILER_TARGET aarch64-linux-android24)

set(CMAKE_SYSROOT "/data/data/com.termux/files/usr/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/sysroot")

set(CMAKE_FIND_ROOT_PATH "/data/data/com.termux/files/usr/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/sysroot")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
