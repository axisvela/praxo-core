cmake_minimum_required(VERSION 3.20)
project(praxo_core C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

include(CTest)

add_library(praxo_core STATIC
    src/files.c
    src/json.c
    src/json_equals.c
    src/toolcall.c
    src/jsonschema.c
    src/plugin.c
    src/vectors_core.c
    src/vectors_agent.c
    src/conformance.c
)
target_include_directories(praxo_core PUBLIC include src)
if(NOT WIN32)
    target_link_libraries(praxo_core PUBLIC m)
endif()

add_executable(praxo-conformance src/main.c)
target_link_libraries(praxo-conformance PRIVATE praxo_core)

add_executable(praxo-c-tests tests/test_core.c)
target_link_libraries(praxo-c-tests PRIVATE praxo_core)

add_test(NAME praxo-conformance COMMAND praxo-conformance)
add_test(NAME praxo-c-tests COMMAND praxo-c-tests)
