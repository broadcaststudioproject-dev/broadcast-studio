cmake_minimum_required(VERSION 3.10)

project(cc_override_test LANGUAGES C CXX)

message(STATUS "FINAL_C_COMPILER=${CMAKE_C_COMPILER}")
message(STATUS "FINAL_CXX_COMPILER=${CMAKE_CXX_COMPILER}")

add_library(test SHARED test.c test.cpp)
