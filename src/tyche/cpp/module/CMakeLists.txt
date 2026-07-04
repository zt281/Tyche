include("${CMAKE_CURRENT_LIST_DIR}/../cmake/TycheBuild.cmake")

add_library(tyche_module STATIC
    "${TYCHE_CPP_DIR}/module.cpp"
    "${TYCHE_CPP_DIR}/message.cpp"
    "${TYCHE_CPP_DIR}/engine/shared_memory_queue.cpp"
)

tyche_apply_common_settings(tyche_module PUBLIC)
tyche_link_zmq(tyche_module PUBLIC)
tyche_link_platform_libraries(tyche_module PUBLIC)
tyche_set_library_output(tyche_module)
set_target_properties(tyche_module PROPERTIES FOLDER "tyche/libraries")

install(TARGETS tyche_module
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
)

install(FILES
    "${TYCHE_CPP_DIR}/types.h"
    "${TYCHE_CPP_DIR}/message.h"
    "${TYCHE_CPP_DIR}/module.h"
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/tyche/cpp"
)
