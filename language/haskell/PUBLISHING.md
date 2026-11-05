# Publishing the Haskell Core

## Status

Source tag `haskell/v0.2.0` maps to Hackage package `praxo-core` version
`0.2.0`. The release workflow is `.github/workflows/haskell-release.yml`.

The prepared source distribution is
`language/haskell/build/cabal/praxo-core-0.2.0.tar.gz` and is also attached to
<https://github.com/axisvela/praxo-core/releases/tag/haskell/v0.2.0>
(sha256 `da23f15d2e4a1e5aec08d85b9e1f96083ce83cc3e9d64b0a5fe19b8dd5693022`).
Use it with the Hackage candidate-upload page at
<https://hackage.haskell.org/packages/candidates/upload>. Both API and manual
uploads currently return `You are not an authorized package uploader`. The
Hackage account must be added to the Uploaders group by the Hackage trustees;
contact the trustees from the upload page or your Hackage account. Candidate
upload still needs a Hackage account; publication may need a maintainer or
trustee approval.

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
- The account must be in Hackage's Uploaders group. A valid API token alone
  still returns `403` if the account is not an authorized uploader; contact the
  Hackage trustees through the upload page to request access.
- Configure the GitHub environment `hackage` and repository secret
  `HACKAGE_TOKEN`.
- Do not store the token in the repository.

## Verify

```bash
cabal update
cabal install praxo-core
```

The Hackage package page and a clean Cabal build are the publication evidence.
