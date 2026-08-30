cmake_minimum_required(VERSION 3.22)

project(phase205 C)

add_executable(phase205 main.c)

target_link_options(phase205 PRIVATE
    -nostdlib
    -nostartfiles
    -Wl,-e,main
    -fuse-ld=/data/data/com.termux/files/home/pocket_pcr_studio/phase205_test/prebuilt/linux-x86_64/bin/ld.lld
)
