cmake_minimum_required(VERSION 3.22)

project(phase203 C)

add_executable(phase203 main.c)

target_link_options(phase203 PRIVATE
    -fuse-ld=/data/data/com.termux/files/home/pocket_pcr_studio/phase203_test/ld-wrapper
    -nostdlib
    -nostartfiles
    -Wl,-e,main
)
