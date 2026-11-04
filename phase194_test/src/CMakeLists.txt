cmake_minimum_required(VERSION 3.20)
project(phase194 C)

set(CMAKE_C_COMPILER "/data/data/com.termux/files/usr/bin/clang")
set(CMAKE_C_FLAGS "--target=aarch64-linux-android21 --sysroot=/data/data/com.termux/files/usr/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/sysroot")
set(CMAKE_EXE_LINKER_FLAGS "-fuse-ld=/data/data/com.termux/files/home/pocket_pcr_studio/phase194_test/ld-wrapper")

add_executable(phase194 main.c)
target_link_options(phase194 PRIVATE "-lunwind")
