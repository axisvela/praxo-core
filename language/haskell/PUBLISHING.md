# Publishing the Haskell Core

## Status

Source tag `haskell/v0.2.0` maps to Hackage package `praxo-core` version
`0.2.0`. The release workflow is `.github/workflows/haskell-release.yml`.

## Build

From `language/haskell/`:

```bash
cabal build --offline all
cabal test --offline
cabal sdist
```

The release workflow also runs the native Python test driver and API snapshot
from the repository root before packing the source distribution.

## Release workflow

The `build` job verifies `praxo-core.cabal` and the `haskell/v*` tag, runs the
declared gates, and uploads the Cabal source distribution. The `publish` job
skips an already published version, otherwise uploads to Hackage.

## Credentials

- Create a Hackage account that can maintain `praxo-core`.
- Configure the GitHub environment `hackage` and repository secret
  `HACKAGE_TOKEN`.
- Do not store the token in the repository.

## Verify

```bash
cabal update
cabal install praxo-core
```

The Hackage package page and a clean Cabal build are the publication evidence.
