# C and C++ Package Recipes

These are source recipes for registry PRs. They are not registry publications
until the corresponding upstream repository accepts and builds them.

## Open PRs

- xmake-repo: https://github.com/xmake-io/xmake-repo/pull/11308
- vcpkg: https://github.com/microsoft/vcpkg/pull/55192
- Conan Center: https://github.com/conan-io/conan-center-index/pull/31502

Both vcpkg and Conan Center require an external CLA signature before their CI
queues run. The PR commits use the GitHub noreply identity
`5856775+hanhuiwen@users.noreply.github.com`.

## Versions

| Package | Source tag | Commit |
| --- | --- | --- |
| `praxo-core` (C) | `c/v0.13.0` | `da4cae049176c5f9d4d6912cdef3f69e1a10db41` |
| `praxo-core-cpp` (C++) | `cpp/v0.9.0` | `da4cae049176c5f9d4d6912cdef3f69e1a10db41` |

Both projects install CMake package configs:

```cmake
find_package(praxo-core CONFIG REQUIRED)
target_link_libraries(app PRIVATE praxo::praxo_core)
```

```cmake
find_package(praxo-cpp CONFIG REQUIRED)
target_link_libraries(app PRIVATE praxo::praxo_cpp)
```

## vcpkg

Ports are under `packaging/vcpkg/ports/`. They use `vcpkg_from_git` with a pinned
commit so the recipe does not depend on a mutable archive checksum.

To test from a vcpkg checkout, copy both directories into `ports/` and run:

```bash
vcpkg install praxo-core
vcpkg install praxo-core-cpp
```

Submit separate PRs to `microsoft/vcpkg`; do not combine the C and C++ ports.

## Conan

Recipes are under `packaging/conan/recipes/`. They clone the pinned commit and
build the corresponding CMake project.

```bash
conan create packaging/conan/recipes/praxo-core
conan create packaging/conan/recipes/praxo-core-cpp
```

Conan Center requires the recipes to live in a PR against
`conan-io/conan-center-index`; the recipes here are the review-ready source.

## xmake

xmake-repo package recipes are under `packaging/xmake/packages/`. They use the
pinned git commit, so they do not depend on a source archive checksum.

```bash
xmake repo --add -g axisvela-local packaging/xmake
xmake require -y praxo-core
xmake require -y praxo-core-cpp
```

Both recipes were locally built with xmake 3.1.2 and MSVC in a consumer project.

## Meson WrapDB and Bazel Central Registry

Upstream build files exist:

- `language/c/meson.build` and `language/cpp/meson.build` are locally built and installed.
- `language/c/xmake.lua` and `language/cpp/xmake.lua` are locally built with xmake 3.1.2.

Registry submission still needs:

- a Meson WrapDB wrap pointing at an archive whose root is the C/C++ project.
- Bazel Central Registry `BUILD`/module metadata.

No registry PR is submitted for those channels until the archive layout or
checksums are validated by the receiving repository.

## Scope

The vcpkg ports declare Android unsupported until Android-specific CI exists.
The C++ package does not automatically link the C Core. C++ process plugin
users must also link `praxo-core` for the C symbols used by
`praxo/plugin_process.hpp`.
