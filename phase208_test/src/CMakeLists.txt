cmake_minimum_required(VERSION 3.22)

project(phase208 C)

add_executable(phase208 main.c)

target_link_options(phase208 PRIVATE
    -nostdlib
    -nostartfiles
    -Wl,-e,main
    -fuse-ld=/data/data/com.termux/files/home/pocket_pcr_studio/phase208_test/ld-wrapper
)
