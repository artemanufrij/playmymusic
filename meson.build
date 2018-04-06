project('com.github.artemanufrij.playmymusic', ['vala', 'c'], version: '0.6.9')


gnome = import('gnome')
i18n = import('i18n')

# Add vapi files
add_project_arguments(
  [
    '--vapidir',
    join_paths(meson.current_source_dir(), 'vapi')
  ],
  language: 'vala'
)


# Add locale support
conf = configuration_data()
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('PREFIX', get_option('prefix'))
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('PACKAGE', meson.project_name())
conf.set_quoted('LOCALE_DIR', join_paths(get_option('prefix'), get_option('localedir')))
conf.set_quoted('DATADIR', join_paths(get_option('prefix'), get_option('datadir')))
conf.set_quoted('PKGDATADIR', join_paths(get_option('prefix'), get_option('datadir'), meson.project_name()))

configure_file(
  output: 'config.h',
  configuration: conf
)
config_h_dir = include_directories('src')

# Arguments C - no gcc warnings
c_args = [
  '-include', 'config.h',
  '-w', '-DGETTEXT_PACKAGE="' + meson.project_name() + '"'
]


subdir('data')
subdir('po')
subdir('schemas')
subdir('src')
meson.add_install_script('meson/post_install.py')
