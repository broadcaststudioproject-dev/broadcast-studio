cmake_minimum_required(VERSION 3.20)
project(phase195 C)

add_executable(phase195 main.c)

target_link_options(phase195 PRIVATE "-lunwind")
