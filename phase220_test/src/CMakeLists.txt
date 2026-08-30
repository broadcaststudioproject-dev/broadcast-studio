cmake_minimum_required(VERSION 3.20)

project(Phase220Test CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(phase220_test main.cpp)

target_link_options(phase220_test PRIVATE
    -unwindlib=none
)
