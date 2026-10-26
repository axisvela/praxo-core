cmake_minimum_required(VERSION 3.20)
project(praxo_cpp CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(CTest)

add_library(praxo_cpp STATIC
    src/agent.cpp
    src/jsonschema.cpp
    src/middleware.cpp
    src/plugin.cpp
    src/runtime.cpp
    src/toolcall.cpp
)
target_include_directories(praxo_cpp PUBLIC include)

add_executable(praxo-cpp-conformance
    conformance/main.cpp
    conformance/run.cpp
)
target_link_libraries(praxo-cpp-conformance PRIVATE praxo_cpp)

add_executable(praxo-cpp-tests tests/core.cpp)
target_link_libraries(praxo-cpp-tests PRIVATE praxo_cpp)

add_test(NAME praxo-cpp-conformance COMMAND praxo-cpp-conformance)
add_test(NAME praxo-cpp-tests COMMAND praxo-cpp-tests)
