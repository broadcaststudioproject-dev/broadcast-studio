cmake_minimum_required(VERSION 3.20)

project(phase108 C)

add_executable(phase108 main.c)

target_link_options(phase108 PRIVATE
    "-L${LIBUNWIND_PATH}"
)
