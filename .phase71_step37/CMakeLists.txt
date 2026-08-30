cmake_minimum_required(VERSION 3.10)

project(explicit_compiler_test LANGUAGES C CXX)

message(STATUS "C_COMPILER=${CMAKE_C_COMPILER}")
message(STATUS "CXX_COMPILER=${CMAKE_CXX_COMPILER}")
message(STATUS "SYSTEM=${CMAKE_SYSTEM_NAME}")
message(STATUS "PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}")

add_library(test SHARED test.c test.cpp)
