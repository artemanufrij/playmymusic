set (CONFIG_FILE ${CMAKE_CURRENT_BINARY_DIR}/Config.vala)
configure_file (${CMAKE_SOURCE_DIR}/Config.vala.cmake ${CONFIG_FILE})

vala_precompile (VALA_C ${CMAKE_PROJECT_NAME}
    Utils/Utils.vala
    Utils/MusicBrainz.vala
    Objects/TracksContainer.vala
    Objects/Playlist.vala
    Objects/Album.vala
    Objects/Artist.vala
    Objects/Track.vala
    Objects/Radio.vala
    Objects/AudioCD.vala
    Services/DataBaseManager.vala
    Services/LocalFilesManager.vala
    Services/TagManager.vala
    Services/LibraryManager.vala
    Services/Player.vala
    Services/MusicBrainzManager.vala
    Services/DeviceManager.vala
    Interfaces/MediaKeys.vala
    Interfaces/SoundIndicator.vala
    Widgets/Artist.vala
    Widgets/Album.vala
    Widgets/Track.vala
    Widgets/TrackTimeLine.vala
    Widgets/Radio.vala
    Widgets/Views/ArtistView.vala
    Widgets/Views/AlbumView.vala
    Widgets/Views/PlaylistView.vala
    Widgets/Views/AlbumsView.vala
    Widgets/Views/RadiosView.vala
    Widgets/Views/ArtistsView.vala
    Widgets/Views/PlaylistsView.vala
    Widgets/Views/AudioCDView.vala
    Dialogs/Preferences.vala
    Settings.vala
    MainWindow.vala
    Application.vala
PACKAGES
    granite
    gtk+-3.0
    sqlite3
    libsoup-2.4
    json-glib-1.0
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
