if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    cmake_minimum_required(VERSION 3.16)
    project(tyche_perf_benchmarks LANGUAGES CXX)
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
    message(STATUS "tests/perf: standalone build mode")
else()
    message(STATUS "tests/perf: subdirectory build mode (parent: ${CMAKE_SOURCE_DIR})")
endif()

include("${CMAKE_CURRENT_LIST_DIR}/../../src/tyche/cpp/cmake/TycheBuild.cmake")

set(TYCHE_PERF_BENCHMARK_TARGETS
    serialization_bench
    flat_message_bench
    shm_bridge_bench
    e2e_latency_bench
    ctp_dispatch_bench
    topic_queue_bench
    ring_buffer_bench
)

add_executable(serialization_bench
    serialization_bench.cpp
    "${TYCHE_CPP_DIR}/message.cpp"
)

add_executable(flat_message_bench
    flat_message_bench.cpp
    "${TYCHE_CPP_DIR}/message.cpp"
)

add_executable(shm_bridge_bench
    shm_bridge_bench.cpp
    "${TYCHE_CPP_DIR}/engine/shared_memory_queue.cpp"
    "${TYCHE_CPP_DIR}/engine/dynamic_library.cpp"
    "${TYCHE_CPP_DIR}/message.cpp"
)

add_executable(e2e_latency_bench
    e2e_latency_bench.cpp
    "${TYCHE_CPP_DIR}/message.cpp"
    "${TYCHE_CPP_DIR}/engine/fast_clock.cpp"
)

add_executable(ctp_dispatch_bench
    ctp_dispatch_bench.cpp
    "${TYCHE_CPP_DIR}/engine/fast_clock.cpp"
)

add_executable(topic_queue_bench
    topic_queue_bench.cpp
    "${TYCHE_CPP_DIR}/engine/topic_queue.cpp"
    "${TYCHE_CPP_DIR}/engine/sharded_topic_map.cpp"
    "${TYCHE_CPP_DIR}/message.cpp"
)

add_executable(ring_buffer_bench
    ring_buffer_bench.cpp
)

foreach(bench_target IN LISTS TYCHE_PERF_BENCHMARK_TARGETS)
    tyche_apply_common_settings("${bench_target}" PRIVATE)
    tyche_link_zmq("${bench_target}" PRIVATE)
    tyche_link_platform_libraries("${bench_target}" PRIVATE)
    tyche_set_benchmark_output("${bench_target}")
    set_target_properties("${bench_target}" PROPERTIES FOLDER "tyche/benchmarks")
endforeach()
