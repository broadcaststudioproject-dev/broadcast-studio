cmake_minimum_required(VERSION 3.22)

project(Arm64CompilerTest C CXX)

message(STATUS "TEST_CMAKE_C_COMPILER=${CMAKE_C_COMPILER}")
message(STATUS "TEST_CMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
message(STATUS "TEST_CMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}")
message(STATUS "TEST_CMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}")

add_executable(test_c test.c)
add_executable(test_cpp test.cpp)
