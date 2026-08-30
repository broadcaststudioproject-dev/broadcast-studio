set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 21)
set(CMAKE_ANDROID_ARCH_ABI arm64-v8a)

set(CMAKE_C_COMPILER "/data/data/com.termux/files/usr/bin/clang")
set(CMAKE_C_COMPILER_TARGET aarch64-linux-android21)

set(CMAKE_SYSROOT "/data/data/com.termux/files/usr/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/sysroot")

set(CMAKE_C_FLAGS
    "--target=aarch64-linux-android21 --sysroot=/data/data/com.termux/files/usr/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
)

set(CMAKE_EXE_LINKER_FLAGS
    "-fuse-ld=/data/data/com.termux/files/home/pocket_pcr_studio/phase195_test/ld-wrapper"
)
