cmake_minimum_required(VERSION 3.20)
project(praxo_cpp_installed_consumer LANGUAGES CXX)

find_package(praxo-cpp CONFIG REQUIRED)
add_executable(praxo-cpp-installed-consumer main.cpp)
target_link_libraries(praxo-cpp-installed-consumer PRIVATE praxo::praxo_cpp)
