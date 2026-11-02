# Releasing the C++ Core

## Status

C++ has no central package-registry publication. The release is a source tag,
`cpp/v0.3.0`, plus the GitHub release/source archive.

## Build and test

Prerequisites: a C++20 compiler, CMake 3.20+, and Python 3.10+.

```bash
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build
ctest --test-dir language/cpp/build --output-on-failure
python language/cpp/api-snapshot.py --check
```

On Windows, if the executables cannot find the compiler runtime, add the
compiler's `bin` directory to `PATH` before running `ctest`. The repository's
`scripts/cpp_behavior_suite.py` performs this step for the behavior lab.

## Release

1. Update `language/cpp/CHANGELOG.md`, `README.md`, and the API snapshot target.
2. Run the gates above.
3. Create the source tag:

```bash
git tag -a cpp/v0.3.0 -m "praxo-core C++ v0.3.0"
git push origin cpp/v0.3.0
```

## Credentials and configuration

- No registry token or package-registry account is used.
- The C++20 standard library is the only library dependency.
- GitHub release publication uses the repository release workflow.

## Verify

```bash
ctest --test-dir language/cpp/build --output-on-failure
python language/cpp/api-snapshot.py --check
```
