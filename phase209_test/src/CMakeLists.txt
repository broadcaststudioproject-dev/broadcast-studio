cmake_minimum_required(VERSION 3.22)
project(phase209 C)

add_executable(phase209 main.c)

target_link_options(phase209 PRIVATE
    -nostdlib
    -nostartfiles
    -Wl,-e,main
    -lunwind
)
