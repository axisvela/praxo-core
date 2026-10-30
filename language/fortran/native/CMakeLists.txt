cmake_minimum_required(VERSION 3.22)
project(praxo_fortran_re2 LANGUAGES CXX)

include(FetchContent)
include(CTest)
set(FETCHCONTENT_UPDATES_DISCONNECTED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(ABSL_PROPAGATE_CXX_STD ON CACHE BOOL "" FORCE)
set(ABSL_BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(RE2_BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(RE2_INSTALL OFF CACHE BOOL "" FORCE)
FetchContent_Declare(abseil
  GIT_REPOSITORY https://github.com/abseil/abseil-cpp.git
  GIT_TAG 76bb24329e8bf5f39704eb10d21b9a80befa7c81)
FetchContent_Declare(re2
  GIT_REPOSITORY https://github.com/google/re2.git
  GIT_TAG 927f5d53caf8111721e734cf24724686bb745f55)
FetchContent_MakeAvailable(abseil re2)

add_library(praxo_re2 SHARED re2_bridge.cc)
target_link_libraries(praxo_re2 PRIVATE re2::re2)
set_target_properties(praxo_re2 PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
  ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
foreach(config DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
  set_target_properties(praxo_re2 PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY_${config} "${CMAKE_BINARY_DIR}/bin"
    LIBRARY_OUTPUT_DIRECTORY_${config} "${CMAKE_BINARY_DIR}/lib"
    ARCHIVE_OUTPUT_DIRECTORY_${config} "${CMAKE_BINARY_DIR}/lib")
endforeach()

if(BUILD_TESTING)
  add_executable(re2_bridge_tests re2_bridge_test.cc)
  target_link_libraries(re2_bridge_tests PRIVATE praxo_re2)
  set_target_properties(re2_bridge_tests PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
  add_test(NAME re2_bridge COMMAND re2_bridge_tests)
endif()

install(TARGETS praxo_re2 RUNTIME DESTINATION bin LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib)
install(FILES re2_bridge.h DESTINATION include)
install(FILES "${re2_SOURCE_DIR}/LICENSE"
  DESTINATION share/licenses/praxo-fortran-re2/re2)
install(FILES "${abseil_SOURCE_DIR}/LICENSE"
  DESTINATION share/licenses/praxo-fortran-re2/abseil)
