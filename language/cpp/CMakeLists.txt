cmake_minimum_required(VERSION 3.20)
project(praxo_cpp CXX)

include(CTest)
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

add_library(praxo_cpp STATIC
    src/agent.cpp
    src/jsonschema.cpp
    src/middleware.cpp
    src/plugin.cpp
    src/runtime.cpp
    src/sse.cpp
    src/toolcall.cpp
    src/harmovela.cpp
)
target_compile_features(praxo_cpp PUBLIC cxx_std_20)
target_include_directories(praxo_cpp PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

install(TARGETS praxo_cpp
    EXPORT praxo-cpp-targets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY include/praxo
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(EXPORT praxo-cpp-targets
    FILE praxo-cpp-targets.cmake
    NAMESPACE praxo::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/praxo-cpp)
configure_package_config_file(
    cmake/praxo-cpp-config.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/praxo-cpp-config.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/praxo-cpp)
write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/praxo-cpp-config-version.cmake
    VERSION 0.9.0
    COMPATIBILITY SameMajorVersion)
install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/praxo-cpp-config.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/praxo-cpp-config-version.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/praxo-cpp)

if(BUILD_TESTING)

add_executable(praxo-cpp-conformance
    conformance/main.cpp
    conformance/run.cpp
)
target_link_libraries(praxo-cpp-conformance PRIVATE praxo_cpp)

add_executable(praxo-cpp-tests tests/core.cpp)
target_link_libraries(praxo-cpp-tests PRIVATE praxo_cpp)

add_executable(praxo-cpp-checkpoint-example examples/checkpoint/main.cpp)
target_link_libraries(praxo-cpp-checkpoint-example PRIVATE praxo_cpp)

add_executable(praxo-cpp-event-sink-example examples/event-sink/main.cpp)
target_link_libraries(praxo-cpp-event-sink-example PRIVATE praxo_cpp)

add_executable(praxo-cpp-streaming-example examples/streaming/main.cpp)
target_link_libraries(praxo-cpp-streaming-example PRIVATE praxo_cpp)

add_executable(praxo-cpp-structured-output-example examples/structured-output/main.cpp)
target_link_libraries(praxo-cpp-structured-output-example PRIVATE praxo_cpp)

add_executable(praxo-cpp-identity-policy-example examples/identity-policy/main.cpp)
target_link_libraries(praxo-cpp-identity-policy-example PRIVATE praxo_cpp)

add_executable(praxo-cpp-hitl-example examples/hitl/main.cpp)
target_link_libraries(praxo-cpp-hitl-example PRIVATE praxo_cpp)

add_executable(praxo-cpp-session-checkpoint-example examples/session-checkpoint/main.cpp)
target_link_libraries(praxo-cpp-session-checkpoint-example PRIVATE praxo_cpp)

add_executable(praxo-cpp-mcp-example examples/mcp/main.cpp)
target_link_libraries(praxo-cpp-mcp-example PRIVATE praxo_cpp)

add_executable(praxo-cpp-consumer-example examples/consumer/main.cpp)
target_link_libraries(praxo-cpp-consumer-example PRIVATE praxo_cpp)

add_executable(praxo-cpp-live-model-example examples/live-model/main.cpp)
target_link_libraries(praxo-cpp-live-model-example PRIVATE praxo_cpp)

add_executable(praxo-cpp-harmovela-tests tests/harmovela.cpp)
target_link_libraries(praxo-cpp-harmovela-tests PRIVATE praxo_cpp)

add_executable(praxo-cpp-provider-tests tests/providers.cpp)
target_link_libraries(praxo-cpp-provider-tests PRIVATE praxo_cpp)

add_executable(praxo-cpp-mcp-tests tests/mcp.cpp)
target_link_libraries(praxo-cpp-mcp-tests PRIVATE praxo_cpp)
add_executable(praxo-cpp-seams-tests tests/seams.cpp)
target_link_libraries(praxo-cpp-seams-tests PRIVATE praxo_cpp)
add_executable(praxo-cpp-delegation-governance-tests
    tests/delegation_governance.cpp)
target_link_libraries(praxo-cpp-delegation-governance-tests PRIVATE praxo_cpp)

add_executable(praxo-cpp-representative-chain-tests
    tests/representative_chain.cpp)
target_link_libraries(praxo-cpp-representative-chain-tests PRIVATE praxo_cpp)

add_executable(praxo-cpp-industrial-edge-tutorial
    Tutorial/industrial-edge/main.cpp)
target_link_libraries(praxo-cpp-industrial-edge-tutorial PRIVATE praxo_cpp)

add_test(NAME praxo-cpp-conformance COMMAND praxo-cpp-conformance)
add_test(NAME praxo-cpp-tests COMMAND praxo-cpp-tests)
add_test(NAME praxo-cpp-harmovela-tests COMMAND praxo-cpp-harmovela-tests)
add_test(NAME praxo-cpp-provider-tests COMMAND praxo-cpp-provider-tests)
add_test(NAME praxo-cpp-mcp-tests COMMAND praxo-cpp-mcp-tests)
add_test(NAME praxo-cpp-seams-tests COMMAND praxo-cpp-seams-tests)
add_test(NAME praxo-cpp-delegation-governance-tests
    COMMAND praxo-cpp-delegation-governance-tests)
add_test(NAME praxo-cpp-representative-chain-tests
    COMMAND praxo-cpp-representative-chain-tests)
add_test(NAME praxo-cpp-industrial-edge-tutorial
    COMMAND praxo-cpp-industrial-edge-tutorial --test)

endif()
