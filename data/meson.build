
i18n.merge_file(
  input: meson.project_name() + '.desktop.in',
  output: meson.project_name() + '.desktop',
  po_dir: join_paths(meson.source_root(), 'po'),
  type: 'desktop',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

i18n.merge_file(
  input: meson.project_name() + '.appdata.xml.in',
  output: meson.project_name() + '.appdata.xml',
  po_dir: join_paths(meson.source_root(), 'po'),
  install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo')
)

test(
    'Validate desktop file',
    find_program('desktop-file-validate'),
    args : join_paths(meson.current_build_dir(), app_name + '.desktop')
)

test(
    'Validate appdata file',
    find_program('appstreamcli'),
    args : ['validate', join_paths(meson.current_build_dir(), app_name + '.appdata.xml')]
)

subdir('icons')
