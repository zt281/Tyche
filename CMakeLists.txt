cmake_minimum_required(VERSION 3.16)
project(TycheEngine CXX)
enable_testing()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(MSVC)
    add_compile_options(/utf-8)
endif()

# ── 项目根目录 ──
get_filename_component(TYCHE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}" ABSOLUTE)
set(TYCHE_ROOT "${TYCHE_ROOT}" CACHE PATH "TycheEngine root directory")

# ── 构建产物分类目录（按功能 × 平台） ──
# 结构：build/{unit_tests,perf_tests,executables,libraries}/{linux,win}/
set(TYCHE_BUILD_DIR "${TYCHE_ROOT}/build")

if(WIN32)
    set(TYCHE_PLATFORM "win")
else()
    set(TYCHE_PLATFORM "linux")
endif()

# 功能分类子目录
set(TYCHE_UNIT_TEST_DIR "${TYCHE_BUILD_DIR}/unit_tests/${TYCHE_PLATFORM}")
set(TYCHE_PERF_TEST_DIR "${TYCHE_BUILD_DIR}/perf_tests/${TYCHE_PLATFORM}")
set(TYCHE_EXECUTABLE_DIR "${TYCHE_BUILD_DIR}/executables/${TYCHE_PLATFORM}")
set(TYCHE_LIBRARY_DIR "${TYCHE_BUILD_DIR}/libraries/${TYCHE_PLATFORM}")

# 创建目录
file(MAKE_DIRECTORY "${TYCHE_UNIT_TEST_DIR}")
file(MAKE_DIRECTORY "${TYCHE_PERF_TEST_DIR}")
file(MAKE_DIRECTORY "${TYCHE_EXECUTABLE_DIR}")
file(MAKE_DIRECTORY "${TYCHE_LIBRARY_DIR}")

# ── 全局默认输出目录 ──
# 默认情况下，可执行文件 -> executables，库 -> libraries
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${TYCHE_EXECUTABLE_DIR}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${TYCHE_LIBRARY_DIR}")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${TYCHE_LIBRARY_DIR}")

foreach(OUTPUTCONFIG ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER ${OUTPUTCONFIG} OUTPUTCONFIG_UPPER)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${OUTPUTCONFIG_UPPER} "${TYCHE_EXECUTABLE_DIR}")
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${OUTPUTCONFIG_UPPER} "${TYCHE_LIBRARY_DIR}")
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${OUTPUTCONFIG_UPPER} "${TYCHE_LIBRARY_DIR}")
endforeach()

message(STATUS "TycheEngine build output structure:")
message(STATUS "  Unit tests:   ${TYCHE_UNIT_TEST_DIR}")
message(STATUS "  Perf tests:   ${TYCHE_PERF_TEST_DIR}")
message(STATUS "  Executables:  ${TYCHE_EXECUTABLE_DIR}")
message(STATUS "  Libraries:    ${TYCHE_LIBRARY_DIR}")

# ── 第三方库目录 ──
set(THIRD_PARTY_DIR "${TYCHE_ROOT}/third_party" CACHE PATH "Third-party directory")

# ── 子项目 ──
add_subdirectory(src/tyche/cpp)
add_subdirectory(src/modules/ctp_gateway_cpp)
add_subdirectory(tests)
