cmake_minimum_required(VERSION 3.18)

project(termux_clang_test C)

set(CMAKE_C_COMPILER clang)

add_executable(test_android test.c)
