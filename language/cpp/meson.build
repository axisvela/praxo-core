project(
  'praxo-cpp',
  'cpp',
  version: '0.9.0',
  license: 'MIT',
  meson_version: '>=1.2.0',
)

pkgconfig = import('pkgconfig')
public_inc = include_directories('include')

sources = files(
  'src/agent.cpp',
  'src/jsonschema.cpp',
  'src/middleware.cpp',
  'src/plugin.cpp',
  'src/runtime.cpp',
  'src/sse.cpp',
  'src/toolcall.cpp',
  'src/harmovela.cpp',
)

libpraxo_cpp = static_library(
  'praxo_cpp',
  sources,
  include_directories: public_inc,
  cpp_args: ['-std=c++20'],
  install: true,
)

install_subdir('include/praxo', install_dir: get_option('includedir'))

praxo_cpp_dep = declare_dependency(
  link_with: libpraxo_cpp,
  include_directories: public_inc,
)

meson.override_dependency('praxo-cpp', praxo_cpp_dep)

pkgconfig.generate(
  libpraxo_cpp,
  name: 'praxo-cpp',
  description: 'C++20 agent runtime',
  version: meson.project_version(),
)
