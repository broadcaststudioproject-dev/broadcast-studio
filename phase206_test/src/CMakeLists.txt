cmake_minimum_required(VERSION 3.22)

project(phase206 C)

add_executable(phase206 main.c)

target_link_options(phase206 PRIVATE
    -nostdlib
    -nostartfiles
    -Wl,-e,main
    -fuse-ld=/data/data/com.termux/files/home/pocket_pcr_studio/phase206_test/ld-wrapper
)
