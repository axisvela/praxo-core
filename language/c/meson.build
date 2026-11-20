project(
  'praxo-core',
  'c',
  version: '0.13.0',
  license: 'MIT',
  meson_version: '>=1.2.0',
)

pkgconfig = import('pkgconfig')
cc = meson.get_compiler('c')
public_inc = include_directories('include')
private_inc = include_directories('src')
m_dep = cc.find_library('m', required: false)

sources = files(
  'src/files.c',
  'src/json.c',
  'src/json_equals.c',
  'src/toolcall.c',
  'src/jsonschema.c',
  'src/plugin.c',
  'src/plugin_process.c',
  'src/core.c',
  'src/core_context.c',
  'src/core_middleware.c',
  'src/openai.c',
  'src/anthropic.c',
  'src/gemini.c',
  'src/harmovela.c',
  'src/mcp.c',
  'src/otel.c',
  'src/retriever.c',
  'src/delegation.c',
  'src/vectors_core.c',
  'src/vectors_agent.c',
  'src/conformance.c',
)

libpraxo_core = static_library(
  'praxo_core',
  sources,
  include_directories: [public_inc, private_inc],
  dependencies: m_dep,
  install: true,
)

install_headers(
  'include/praxo.h',
  'include/praxo_core.h',
  'include/praxo_plugin_process.h',
)

praxo_core_dep = declare_dependency(
  link_with: libpraxo_core,
  include_directories: public_inc,
  dependencies: m_dep,
)

meson.override_dependency('praxo-core', praxo_core_dep)

pkgconfig.generate(
  libpraxo_core,
  name: 'praxo-core',
  description: 'Embeddable C agent runtime',
  version: meson.project_version(),
)
