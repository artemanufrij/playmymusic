set (CONFIG_FILE ${CMAKE_CURRENT_BINARY_DIR}/Config.vala)
configure_file (${CMAKE_SOURCE_DIR}/Config.vala.cmake ${CONFIG_FILE})

vala_precompile (VALA_C ${CMAKE_PROJECT_NAME}
    Objects/Album.vala
    Objects/Artist.vala
    Objects/Track.vala
    Services/DataBaseManager.vala
    Services/LocalFilesManager.vala
    Services/TagManager.vala
    Services/LibraryManager.vala
    Widgets/Album.vala
    MainWindow.vala
    Application.vala
PACKAGES
    granite
    gtk+-3.0
    sqlite3
    gstreamer-pbutils-1.0
    gstreamer-tag-1.0
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/vapi
    --target-glib=2.32
    --thread
)

add_executable (${CMAKE_PROJECT_NAME} ${VALA_C})
target_link_libraries (${CMAKE_PROJECT_NAME} ${DEPS_LIBRARIES})

# Installation
install (TARGETS ${CMAKE_PROJECT_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_FULL_BINDIR})
