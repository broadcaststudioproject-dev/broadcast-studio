set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER "/data/data/com.termux/files/usr/bin/aarch64-linux-android-clang")
set(CMAKE_CXX_COMPILER "/data/data/com.termux/files/usr/bin/aarch64-linux-android-clang++")

set(CMAKE_SYSROOT "/data/data/com.termux/files/usr/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/sysroot")

set(CMAKE_C_FLAGS "--target=aarch64-linux-android21 --sysroot=/data/data/com.termux/files/usr/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/sysroot")
set(CMAKE_CXX_FLAGS "--target=aarch64-linux-android21 --sysroot=/data/data/com.termux/files/usr/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/sysroot")

set(CMAKE_EXE_LINKER_FLAGS "--target=aarch64-linux-android21 --sysroot=/data/data/com.termux/files/usr/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/sysroot")
set(CMAKE_SHARED_LINKER_FLAGS "--target=aarch64-linux-android21 --sysroot=/data/data/com.termux/files/usr/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/sysroot")
