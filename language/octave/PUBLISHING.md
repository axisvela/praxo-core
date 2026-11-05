# Publishing the Octave Core

Source tag `octave/v0.2.1` maps to Octave package `praxo-core` version
`0.2.1`. The package archive is generated from this directory and published on
the `octave/v0.2.1` GitHub release.

## Build

From the repository root:

```bash
python language/octave/build_octave_package.py
```

This writes `language/octave/build/octave/praxo-core-0.2.1.tar.gz` with a root
`DESCRIPTION`, `inst/+praxo`, `LICENSE`, and README. The `+praxo` sources come
from the shared `language/matlab-octave-core` tree. The archive is published at:

<https://github.com/axisvela/praxo-core/releases/download/octave/v0.2.1/praxo-core-0.2.1.tar.gz>

## Octave Packages

The package entry is in PR #875:
<https://github.com/gnu-octave/packages/pull/875>. The YAML uses package name
and permalink `praxo-core`, version `0.2.1`, the archive SHA256, and dependencies
`octave (>= 7.0.0)` and `pkg`.

After merge, verify in a clean Octave environment:

```octave
pkg install -forge praxo-core
pkg load praxo-core
assert(strcmp(praxo.sdk_version(), '0.2.1'))
```

Run `python language/octave/run-tests.py --octave octave-cli` and the API
snapshot before publishing. The archive must contain `inst/+praxo`; do not
publish the monorepo root as an Octave package.
