# C and C++ Package Recipes

These are source recipes for registry PRs. They are not registry publications
until the corresponding upstream repository accepts and builds them.

## Versions

| Package | Source tag | Commit |
| --- | --- | --- |
| `praxo-core` (C) | `c/v0.13.0` | `d6af4a07f6554ed4b748dd82bdecf81d1e851b69` |
| `praxo-core-cpp` (C++) | `cpp/v0.9.0` | `d6af4a07f6554ed4b748dd82bdecf81d1e851b69` |

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

## xmake, Meson WrapDB, Bazel Central Registry

These require additional upstream metadata:

- xmake-repo expects a stable source archive and checksum.
- Meson WrapDB expects a `meson.build` in the upstream project.
- Bazel Central Registry expects Bazel `BUILD`/module metadata.

No recipes are committed for those channels until the required archive
checksum or build metadata is generated and tested.

## Scope

The C++ package does not automatically link the C Core. C++ process plugin
users must also link `praxo-core` for the C symbols used by
`praxo/plugin_process.hpp`.
