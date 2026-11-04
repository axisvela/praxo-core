# Releasing the C++ Core

## Status

Source tag `cpp/v0.4.0`. There is no central C++ package-registry publication.

## Candidate registries

- **vcpkg**: add a port under `ports/praxo-core-cpp` and open a pull request to
  <https://github.com/microsoft/vcpkg>.
- **ConanCenter**: add a recipe under `recipes/praxo-core-cpp` and open a pull
  request to <https://github.com/conan-io/conan-center-index>.

The port or recipe should use tag `cpp/v0.4.0`, build the CMake target, install
public headers, and run a clean consumer build. Both registries use GitHub pull
requests; no separate account is required.

## Build and test

```bash
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build
ctest --test-dir language/cpp/build --output-on-failure
python language/cpp/api-snapshot.py --check
```

On Windows, if the executables cannot find the compiler runtime, add the
compiler's `bin` directory to `PATH` before running `ctest`.

## Release

1. Update `language/cpp/CHANGELOG.md`, `README.md`, and the API snapshot target.
2. Run the gates above.
3. Tag and push `cpp/v0.4.0`.
4. Add the vcpkg port or Conan recipe and verify a clean consumer build.
