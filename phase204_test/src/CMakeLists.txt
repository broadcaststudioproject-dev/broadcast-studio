cmake_minimum_required(VERSION 3.22)
project(phase204 C)

add_executable(phase204 main.c)

target_link_options(phase204 PRIVATE
    -nostdlib
    -nostartfiles
    -Wl,-e,main
    -fuse-ld=/data/data/com.termux/files/home/pocket_pcr_studio/phase204_test/prebuilt/linux-x86_64/bin/ld.lld
)
