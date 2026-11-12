cmake_minimum_required(VERSION 3.20)
project(praxo_core C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

include(CTest)
include(GNUInstallDirs)

add_library(praxo_core STATIC
    src/files.c
    src/json.c
    src/json_equals.c
    src/toolcall.c
    src/jsonschema.c
    src/plugin.c
    src/core.c
    src/core_context.c
    src/core_middleware.c
    src/openai.c
    src/anthropic.c
    src/gemini.c
    src/harmovela.c
    src/mcp.c
    src/vectors_core.c
    src/vectors_agent.c
    src/conformance.c
)
target_include_directories(praxo_core PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
if(NOT WIN32)
    target_link_libraries(praxo_core PUBLIC m)
endif()
install(TARGETS praxo_core
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES include/praxo.h include/praxo_core.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

add_executable(praxo-conformance src/main.c)
target_link_libraries(praxo-conformance PRIVATE praxo_core)

add_executable(praxo-c-tests tests/test_core.c)
target_link_libraries(praxo-c-tests PRIVATE praxo_core)

add_executable(praxo-c-core-tests tests/test_core_api.c)
target_link_libraries(praxo-c-core-tests PRIVATE praxo_core)

add_executable(praxo-c-adapter-tests tests/test_vector_adapters.c)
target_link_libraries(praxo-c-adapter-tests PRIVATE praxo_core)

add_executable(praxo-c-openai-tests tests/test_openai.c)
target_link_libraries(praxo-c-openai-tests PRIVATE praxo_core)

add_executable(praxo-c-anthropic-tests tests/test_anthropic.c)
target_link_libraries(praxo-c-anthropic-tests PRIVATE praxo_core)

add_executable(praxo-c-gemini-tests tests/test_gemini.c)
target_link_libraries(praxo-c-gemini-tests PRIVATE praxo_core)

add_executable(praxo-c-harmovela-tests tests/test_harmovela.c)
target_link_libraries(praxo-c-harmovela-tests PRIVATE praxo_core)

add_executable(praxo-c-mcp-tests tests/test_mcp.c)
target_link_libraries(praxo-c-mcp-tests PRIVATE praxo_core)

if(MSVC)
    target_compile_options(praxo-c-tests PRIVATE /UNDEBUG)
    target_compile_options(praxo-c-core-tests PRIVATE /UNDEBUG)
    target_compile_options(praxo-c-adapter-tests PRIVATE /UNDEBUG)
    target_compile_options(praxo-c-openai-tests PRIVATE /UNDEBUG)
    target_compile_options(praxo-c-anthropic-tests PRIVATE /UNDEBUG)
    target_compile_options(praxo-c-gemini-tests PRIVATE /UNDEBUG)
    target_compile_options(praxo-c-harmovela-tests PRIVATE /UNDEBUG)
    target_compile_options(praxo-c-mcp-tests PRIVATE /UNDEBUG)
else()
    target_compile_options(praxo-c-tests PRIVATE -UNDEBUG)
    target_compile_options(praxo-c-core-tests PRIVATE -UNDEBUG)
    target_compile_options(praxo-c-adapter-tests PRIVATE -UNDEBUG)
    target_compile_options(praxo-c-openai-tests PRIVATE -UNDEBUG)
    target_compile_options(praxo-c-anthropic-tests PRIVATE -UNDEBUG)
    target_compile_options(praxo-c-gemini-tests PRIVATE -UNDEBUG)
    target_compile_options(praxo-c-harmovela-tests PRIVATE -UNDEBUG)
    target_compile_options(praxo-c-mcp-tests PRIVATE -UNDEBUG)
endif()

add_test(NAME praxo-conformance COMMAND praxo-conformance)
add_test(NAME praxo-c-tests COMMAND praxo-c-tests)
add_test(NAME praxo-c-core-tests COMMAND praxo-c-core-tests)
add_test(NAME praxo-c-adapter-tests COMMAND praxo-c-adapter-tests)
add_test(NAME praxo-c-openai-tests COMMAND praxo-c-openai-tests)
add_test(NAME praxo-c-anthropic-tests COMMAND praxo-c-anthropic-tests)
add_test(NAME praxo-c-gemini-tests COMMAND praxo-c-gemini-tests)
add_test(NAME praxo-c-harmovela-tests COMMAND praxo-c-harmovela-tests)
add_test(NAME praxo-c-mcp-tests COMMAND praxo-c-mcp-tests)

if(BUILD_TESTING)
    find_package(Python3 3.10 REQUIRED COMPONENTS Interpreter)
    include(cmake/ApiCompiler.cmake)
    praxo_api_compiler_args(PRAXO_API_COMPILER_ARGS "${CMAKE_C_COMPILER_ID}"
        "${CMAKE_C_COMPILER_FRONTEND_VARIANT}" "${CMAKE_C_COMPILER}")
    add_test(NAME praxo-c-api-snapshot
        COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/api-snapshot.py"
            --check ${PRAXO_API_COMPILER_ARGS})
    add_test(NAME praxo-c-api-snapshot-tests
        COMMAND "${Python3_EXECUTABLE}" -m unittest discover
            -s "${CMAKE_CURRENT_SOURCE_DIR}/tests" -p test_api_snapshot.py -v)
    add_test(NAME praxo-c-inventory-tests
        COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_conformance_inventory.py"
            $<TARGET_FILE:praxo-conformance>)
    if(PRAXO_API_COMPILER_ARGS)
        set_tests_properties(praxo-c-api-snapshot-tests PROPERTIES
            ENVIRONMENT "PRAXO_API_TEST_COMPILER=${CMAKE_C_COMPILER}")
    endif()
endif()
