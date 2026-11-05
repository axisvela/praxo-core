# Publishing the Nim Core

## Status

Source tag `nim/v0.1.1` maps to package `praxo_core` version `0.1.1`. The
Nimble package is published from the split repository
<https://github.com/axisvela/praxo-core-nim>, which has `praxo_core.nimble` and
`src/` at its root. `nim-lang/packages` points `praxo_core` at the split
repository; the old monorepo entry with `"subdir": "language/nim"` made
nimpkgs and root-only tooling mark the package broken. Nimble derives package
versions from git tags, not from the `version` field alone.

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
3. Commit, tag `nim/vX.Y.Z`, and push the tag in the main repository.
4. Sync the same `praxo_core.nimble`, `src/`, `LICENSE`, and `README.md` to
   `axisvela/praxo-core-nim`, bump its `VERSION`, commit, tag `vX.Y.Z`, and
   push the branch and tag.
5. Verify:
   ```bash
   nimble install praxo_core
   ```

## Package list

No registry account or secret is required. The package list is maintained by a
pull request to <https://github.com/nim-lang/packages>; keep the existing
`praxo_core` entry pointed at `axisvela/praxo-core-nim`. nimpkgs crawls that
list and reads the split repository root; do not restore `"subdir"`.
