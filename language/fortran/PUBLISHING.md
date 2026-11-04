# Releasing the Fortran Core

## Status

Source tag `fortran/v0.6.0`. The package is not in the fpm registry.

The upstream fpm registry is a playground and is currently unavailable: the
frontend returns `503 DEPLOYMENT_PAUSED` and the backend returns `500`.
Registration and publication are blocked until the upstream owners restore it.
Keep Fortran source-tag-only in the meantime.

## fpm registry

When the registry is available, it requires an account, namespace, and token:

1. Create an account and namespace at the fpm registry.
2. Generate a token for the namespace.
3. Run `fpm publish --token <token>`.
4. Store the token as `FPM_REGISTRY_TOKEN` for CI.

Add an `fpm.toml` manifest with package name `praxo-core`, version `0.6.0`,
license `MIT`, and the Core source layout. The Core also needs the RE2 C++
bridge; confirm that fpm can build it or document it as an external prerequisite
before publishing.

## Build and test

Prerequisites: GNU Fortran, a C++17 compiler, CMake 3.22+, Ninja, Git, and
Python 3.10+.

```bash
python language/fortran/run-tests.py
python language/fortran/api-snapshot.py --check
```

## Release

1. Update `language/fortran/CHANGELOG.md`, `README.md`, `SETUP.md`, and the API
   snapshot target.
2. Run the gates above.
3. Tag and push `fortran/v0.6.0`.
4. Publish the fpm package and verify `fpm install praxo-core`.
