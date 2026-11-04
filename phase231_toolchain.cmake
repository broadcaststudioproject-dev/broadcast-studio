set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 21)
set(CMAKE_ANDROID_ARCH_ABI arm64-v8a)

set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)

set(CMAKE_CXX_FLAGS_INIT "-stdlib=libc++ -unwindlib=none")

set(UNWIND_LIB
    "/data/data/com.termux/files/home/../usr/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/lib/clang/19/lib/linux/aarch64/libunwind.a")

set(CMAKE_EXE_LINKER_FLAGS_INIT "${UNWIND_LIB}")
