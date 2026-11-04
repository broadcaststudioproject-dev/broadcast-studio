cmake_minimum_required(VERSION 3.20)

project(phase191 C)

add_executable(phase191 main.c)

target_compile_options(phase191 PRIVATE
    -O3
    -DNDEBUG
)

set_target_properties(phase191 PROPERTIES
    LINK_FLAGS "-fuse-ld=/data/data/com.termux/files/home/pocket_pcr_studio/phase191_test/ld-wrapper"
)
