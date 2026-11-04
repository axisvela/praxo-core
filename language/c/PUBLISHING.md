# Publishing the C Core

Source tag `c/v0.6.0`. There is no central C package registry publication.

Candidate registries:

- **vcpkg**: add a port under `ports/praxo-core` and open a pull request to
  <https://github.com/microsoft/vcpkg>.
- **ConanCenter**: add a recipe under `recipes/praxo-core` and open a pull
  request to <https://github.com/conan-io/conan-center-index>.

The port or recipe should use tag `c/v0.6.0`, build the CMake target, install
public headers, and run a clean consumer build. Run the CMake tests and API
snapshot first. Both registries use GitHub pull requests; no separate account is
required.
