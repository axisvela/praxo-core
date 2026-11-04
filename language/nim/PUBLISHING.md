# Publishing the Nim Core

## Status

Source tag `nim/v0.1.1` maps to package `praxo_core` version `0.1.1`. The
package is listed in `nim-lang/packages` with `"subdir": "language/nim"`.
Nimble derives package versions from git tags, not from the `version` field
alone.

## Release

1. Update `praxo_core.nimble`, the API snapshot, and the release notes.
2. Run the native gates from the repository root:
   ```bash
   python language/nim/api-snapshot.py --check
   nim c --path:language/nim/src --hints:off --out:build/praxo-nim-conformance language/nim/conformance/run.nim
   ./build/praxo-nim-conformance
   nim c --path:language/nim/src --hints:off --out:build/praxo-nim-tests language/nim/tests/run_tests.nim
   ./build/praxo-nim-tests
   ```
3. Commit, tag `nim/vX.Y.Z`, and push the tag.
4. Verify:
   ```bash
   nimble install praxo_core
   ```

## Package list

No registry account or secret is required. The package list is maintained by a
pull request to <https://github.com/nim-lang/packages>; keep the existing
`praxo_core` entry and its `subdir` accurate for future releases.
