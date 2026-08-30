cmake_minimum_required(VERSION 3.22)

project(Phase281Test C)

add_executable(phase281_test src/main.c)

target_link_options(phase281_test PRIVATE
    "-L${UNWIND_DIR}"
)

target_link_libraries(phase281_test PRIVATE
    "-l:libunwind.a"
    dl
    c
)
