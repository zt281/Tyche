include_guard(DIRECTORY)

include(GNUInstallDirs)

get_filename_component(TYCHE_CPP_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

if(NOT DEFINED TYCHE_ROOT)
    get_filename_component(TYCHE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../.." ABSOLUTE)
    set(TYCHE_ROOT "${TYCHE_ROOT}" CACHE PATH "TycheEngine root directory")
endif()

if(NOT DEFINED THIRD_PARTY_DIR)
    set(THIRD_PARTY_DIR "${TYCHE_ROOT}/third_party" CACHE PATH "Third-party directory")
endif()

if(WIN32)
    set(TYCHE_PLATFORM_DIR "win")
else()
    set(TYCHE_PLATFORM_DIR "linux")
endif()

set(TYCHE_OUTPUT_ROOT "${TYCHE_ROOT}/build")
set(TYCHE_RUNTIME_OUTPUT_DIR "${TYCHE_OUTPUT_ROOT}/executables/${TYCHE_PLATFORM_DIR}")
set(TYCHE_LIBRARY_OUTPUT_DIR "${TYCHE_OUTPUT_ROOT}/libraries/${TYCHE_PLATFORM_DIR}")
set(TYCHE_BENCHMARK_OUTPUT_DIR "${TYCHE_OUTPUT_ROOT}/perf_tests/${TYCHE_PLATFORM_DIR}")

set_property(GLOBAL PROPERTY USE_FOLDERS ON)

function(tyche_set_output_directories target runtime_dir library_dir archive_dir pdb_dir)
    set_target_properties("${target}" PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${runtime_dir}"
        LIBRARY_OUTPUT_DIRECTORY "${library_dir}"
        ARCHIVE_OUTPUT_DIRECTORY "${archive_dir}"
        PDB_OUTPUT_DIRECTORY "${pdb_dir}"
        COMPILE_PDB_OUTPUT_DIRECTORY "${pdb_dir}"
    )

    foreach(config IN LISTS CMAKE_CONFIGURATION_TYPES)
        string(TOUPPER "${config}" config_upper)
        set_target_properties("${target}" PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY_${config_upper} "${runtime_dir}"
            LIBRARY_OUTPUT_DIRECTORY_${config_upper} "${library_dir}"
            ARCHIVE_OUTPUT_DIRECTORY_${config_upper} "${archive_dir}"
            PDB_OUTPUT_DIRECTORY_${config_upper} "${pdb_dir}"
            COMPILE_PDB_OUTPUT_DIRECTORY_${config_upper} "${pdb_dir}"
        )
    endforeach()
endfunction()

function(tyche_set_executable_output target)
    tyche_set_output_directories(
        "${target}"
        "${TYCHE_RUNTIME_OUTPUT_DIR}"
        "${TYCHE_LIBRARY_OUTPUT_DIR}"
        "${TYCHE_LIBRARY_OUTPUT_DIR}"
        "${TYCHE_RUNTIME_OUTPUT_DIR}"
    )
endfunction()

function(tyche_set_library_output target)
    tyche_set_output_directories(
        "${target}"
        "${TYCHE_LIBRARY_OUTPUT_DIR}"
        "${TYCHE_LIBRARY_OUTPUT_DIR}"
        "${TYCHE_LIBRARY_OUTPUT_DIR}"
        "${TYCHE_LIBRARY_OUTPUT_DIR}"
    )
endfunction()

function(tyche_set_benchmark_output target)
    tyche_set_output_directories(
        "${target}"
        "${TYCHE_BENCHMARK_OUTPUT_DIR}"
        "${TYCHE_LIBRARY_OUTPUT_DIR}"
        "${TYCHE_LIBRARY_OUTPUT_DIR}"
        "${TYCHE_BENCHMARK_OUTPUT_DIR}"
    )
endfunction()

function(tyche_link_platform_libraries target scope)
    if(WIN32)
        target_link_libraries("${target}" ${scope} ws2_32 iphlpapi)
    else()
        target_link_libraries("${target}" ${scope} pthread)
    endif()
endfunction()

function(tyche_apply_common_settings target scope)
    target_compile_features("${target}" ${scope} cxx_std_17)
    target_compile_definitions("${target}" ${scope} MSGPACK_NO_BOOST)

    set(include_dirs
        "${TYCHE_ROOT}/src"
        "${THIRD_PARTY_DIR}/cppzmq"
        "${THIRD_PARTY_DIR}/msgpack-c/include"
        "${THIRD_PARTY_DIR}"
    )

    if(ZMQ_INCLUDE_DIR)
        list(APPEND include_dirs "${ZMQ_INCLUDE_DIR}")
    endif()

    target_include_directories("${target}" ${scope} ${include_dirs})

    if(ZMQ_INCLUDE_DIRS)
        target_include_directories("${target}" ${scope} ${ZMQ_INCLUDE_DIRS})
    endif()

    if(MSVC)
        target_compile_options("${target}" PRIVATE /utf-8)
    endif()
endfunction()

function(tyche_link_zmq target scope)
    if(ZMQ_LIBRARY)
        target_link_libraries("${target}" ${scope} ${ZMQ_LIBRARY})
    endif()

    if(ZMQ_LIBRARIES)
        target_link_libraries("${target}" ${scope} ${ZMQ_LIBRARIES})
    endif()

    if(NOT ZMQ_LIBRARY AND NOT ZMQ_LIBRARIES)
        message(FATAL_ERROR "No libzmq library was found or configured")
    endif()
endfunction()

option(TYCHE_BUILD_LIBZMQ "Build libzmq from third_party source" OFF)

if(NOT TYCHE_BUILD_LIBZMQ)
    find_path(ZMQ_INCLUDE_DIR zmq.h
        HINTS ENV ZMQ_DIR
        PATH_SUFFIXES include
    )
    find_library(ZMQ_LIBRARY
        NAMES zmq libzmq
        HINTS ENV ZMQ_DIR
        PATH_SUFFIXES lib
    )

    if(NOT ZMQ_INCLUDE_DIR OR NOT ZMQ_LIBRARY)
        message(STATUS "libzmq not found via find_path/find_library; trying pkg-config")
        find_package(PkgConfig QUIET)
        if(PkgConfig_FOUND)
            pkg_check_modules(ZMQ QUIET libzmq)
        endif()
    endif()

    if((NOT ZMQ_INCLUDE_DIR OR NOT ZMQ_LIBRARY) AND NOT ZMQ_FOUND)
        message(STATUS "libzmq not found. Falling back to third_party/libzmq")
        set(TYCHE_BUILD_LIBZMQ ON)
    endif()
endif()

if(TYCHE_BUILD_LIBZMQ)
    set(ZMQ_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(BUILD_SHARED OFF CACHE BOOL "" FORCE)
    set(BUILD_STATIC ON CACHE BOOL "" FORCE)
    set(WITH_DOCS OFF CACHE BOOL "" FORCE)
    set(WITH_PERF_TOOL OFF CACHE BOOL "" FORCE)

    if(NOT TARGET libzmq-static)
        message(STATUS "Building libzmq from ${THIRD_PARTY_DIR}/libzmq")
        add_subdirectory("${THIRD_PARTY_DIR}/libzmq" "${CMAKE_BINARY_DIR}/libzmq" EXCLUDE_FROM_ALL)
    endif()

    set(ZMQ_INCLUDE_DIR "${THIRD_PARTY_DIR}/libzmq/include")
    set(ZMQ_LIBRARY libzmq-static)

    if(TARGET libzmq-static)
        tyche_set_library_output(libzmq-static)
        set_target_properties(libzmq-static PROPERTIES FOLDER "third_party")
    endif()
endif()
