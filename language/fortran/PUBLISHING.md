# Releasing the Fortran Core

## Status

Fortran has no central package-registry publication. The release is a source
tag, `fortran/v0.5.0`, plus the GitHub release/source archive.

## Build and test

Prerequisites: GNU Fortran, a C++17 compiler, CMake 3.22+, Ninja, Git, and
Python 3.10+. The first build obtains the pinned RE2/Abseil sources.

```bash
python language/fortran/run-tests.py
python language/fortran/api-snapshot.py --check
```

The driver builds the native RE2 bridge, runs 104 agent assertions, 59 JSON
assertions, 84 contract assertions, 63 vectors, and the RE2/Unicode assertions.

## Release

1. Update `language/fortran/CHANGELOG.md`, `README.md`, `SETUP.md`, and the API
   snapshot target.
2. Run the gates above.
3. Create the source tag:

```bash
git tag -a fortran/v0.5.0 -m "praxo-core Fortran v0.5.0"
git push origin fortran/v0.5.0
```

## Credentials and configuration

- No registry token or package-registry account is used.
- The RE2 bridge is a native build dependency, not a vendored artifact.
- GitHub release publication uses the repository release workflow.

## Verify

```bash
python language/fortran/run-tests.py
python language/fortran/api-snapshot.py --check
```

Consumers use the source tag/archive and the build instructions in
`language/fortran/SETUP.md`.
