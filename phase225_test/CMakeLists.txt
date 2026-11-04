cmake_minimum_required(VERSION 3.20)

project(phase225_test LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(phase225_test src/main.cpp)

target_compile_options(phase225_test PRIVATE
    -stdlib=libc++
)

target_link_options(phase225_test PRIVATE
    -stdlib=libc++
    -unwindlib=none
)
