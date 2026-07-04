cmake_minimum_required(VERSION 3.16)

set(TYCHE_CPP_STANDALONE OFF)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(TYCHE_CPP_STANDALONE ON)
    project(tyche_cpp LANGUAGES CXX)
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
    message(STATUS "src/tyche/cpp: standalone build mode")
else()
    message(STATUS "src/tyche/cpp: composition mode (parent: ${CMAKE_SOURCE_DIR})")
endif()

include("${CMAKE_CURRENT_LIST_DIR}/cmake/TycheBuild.cmake")

option(TYCHE_BUILD_MODULE_API "Build the Tyche C++ module API library" ON)

set(TYCHE_BUILD_ENGINE_DEFAULT "${TYCHE_CPP_STANDALONE}")
option(TYCHE_BUILD_ENGINE "Build the Tyche engine executable" "${TYCHE_BUILD_ENGINE_DEFAULT}")

set(TYCHE_BUILD_PERF_BENCHMARKS_DEFAULT "${TYCHE_CPP_STANDALONE}")
if(DEFINED TYCHE_BUILD_BENCHMARKS AND NOT DEFINED TYCHE_BUILD_PERF_BENCHMARKS)
    set(TYCHE_BUILD_PERF_BENCHMARKS "${TYCHE_BUILD_BENCHMARKS}" CACHE BOOL
        "Build Tyche C++ performance benchmarks"
    )
endif()
option(TYCHE_BUILD_PERF_BENCHMARKS "Build Tyche C++ performance benchmarks"
    "${TYCHE_BUILD_PERF_BENCHMARKS_DEFAULT}"
)

if(TYCHE_BUILD_MODULE_API)
    add_subdirectory(module)
endif()

if(TYCHE_BUILD_ENGINE)
    add_subdirectory(engine)
endif()

if(TYCHE_BUILD_PERF_BENCHMARKS)
    add_subdirectory("${TYCHE_ROOT}/tests/perf" "${CMAKE_BINARY_DIR}/tests_perf")
endif()
