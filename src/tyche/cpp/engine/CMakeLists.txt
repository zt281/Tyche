include("${CMAKE_CURRENT_LIST_DIR}/../cmake/TycheBuild.cmake")

add_executable(tyche_engine
    main.cpp
    engine.cpp
    topic_queue.cpp
    sharded_topic_map.cpp
    heartbeat_manager.cpp
    dead_letter_store.cpp
    shared_memory_queue.cpp
    dynamic_library.cpp
    shared_memory_bridge.cpp
    fast_clock.cpp
    thread_affinity.cpp
    "${TYCHE_CPP_DIR}/message.cpp"
)

tyche_apply_common_settings(tyche_engine PRIVATE)
tyche_link_zmq(tyche_engine PRIVATE)
tyche_link_platform_libraries(tyche_engine PRIVATE)
tyche_set_executable_output(tyche_engine)
set_target_properties(tyche_engine PROPERTIES FOLDER "tyche/apps")

install(TARGETS tyche_engine
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)

install(FILES
    engine.h
    heartbeat_manager.h
    dead_letter_store.h
    topic_queue.h
    ring_buffer.h
    shared_memory_queue.h
    dynamic_library.h
    shared_memory_bridge.h
    module_interface.h
    adaptive_spin.h
    fast_clock.h
    topic_queue_index.h
    rcu_snapshot.h
    thread_affinity.h
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/tyche/cpp/engine"
)
