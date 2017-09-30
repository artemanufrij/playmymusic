cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)

project (com.github.artemanufrij.playmymusic)
include (GNUInstallDirs)
set (DATADIR "${CMAKE_INSTALL_FULL_DATAROOTDIR}")
set (PKGDATADIR "${DATADIR}/${CMAKE_PROJECT_NAME}")
set (GETTEXT_PACKAGE ${CMAKE_PROJECT_NAME})
add_definitions ("-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\"")
#########################################################
# Only alter stuff below if you know what you are doing #
#########################################################

# Load Custom CMake modules
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# Check definitions and packages
find_package (PkgConfig)
pkg_check_modules (DEPS REQUIRED
    gtk+-3.0>=3.11.6
    granite
    sqlite3
    libsoup-2.4
    gstreamer-tag-1.0
    gstreamer-pbutils-1.0
)

# Comment this out to enable C compiler warnings
add_definitions (-w)

add_definitions (${DEPS_CFLAGS})
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})

# Vala Stuff
include (ValaPrecompile)
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.21.2" MINIMUM)

add_subdirectory (src)
add_subdirectory (data)
#add_subdirectory (po)
add_subdirectory (schemas)
