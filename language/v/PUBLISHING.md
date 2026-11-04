# Publishing the V Core

## Status

Source tag `v/v0.1.1` maps to package version `0.1.1`. VPM authentication uses
GitHub; no separate VPM account is required.

## Packaging constraint

VPM expects `v.mod` at the repository root and plain semantic-version tags.
This monorepo keeps the module under `language/v`, so publish a split mirror,
for example `axisvela/praxo-core-v`, with:

- `v.mod`
- `praxo/`
- `LICENSE`
- `README.md`

Tag the mirror with plain versions such as `0.1.1`.

## Release

1. Update `v.mod`, the API snapshot, and release notes.
2. Run:
   ```bash
   python language/v/api-snapshot.py --check
   v -cc tcc -gc none -o build/praxo-v-conformance language/v/conformance/run.v
   ./build/praxo-v-conformance
   v -cc tcc -gc none -o build/praxo-v-tests language/v/tests/run.v
   ./build/praxo-v-tests
   ```
3. Tag and push the split mirror.
4. Register the package through VPM using GitHub authentication and verify:
   ```bash
   v install praxo
   ```
