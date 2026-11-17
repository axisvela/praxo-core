# Publishing the MATLAB/Octave Core

Source tag `matlab/v0.7.0`. The package is published on MATLAB File Exchange:
<https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core>. It is
not published to Octave Packages.

Octave verification is not MATLAB verification. The currently published
compatibility metadata is not an independently verified MATLAB support matrix.
Do not repeat "Compatible with any release" or all-platform support claims.
The public limitation is in [README.md](README.md).

## Build a MATLAB package

In MATLAB, from this directory:

```matlab
package_toolbox
```

The packager first runs the shared `language/matlab-octave-core/run_tests.m`
suite in the actual MATLAB process. It sets minimum and maximum release to that
MATLAB release and enables only the host platform, not MATLAB Online or all OSes.
This is source execution evidence, not an installed-artifact test. The packager
has not yet been independently executed in MATLAB.

This creates `praxo-core-0.7.0.mltbx` containing `+praxo`, `README.md`,
`LICENSE`, and `toolbox-image.png`. The image is
`language/matlab/toolbox-image.png`; use it as the File Exchange thumbnail.

MATLAB package names must be identifiers matching `[A-Za-z][A-Za-z0-9_]*`.
Use `praxo_core` as the package name; keep `PRAXO-CORE` only as the display
name. `package_toolbox.m` sets both accordingly.

## Generated Upload ZIP (2026-11-16)

MATLAB is not installed on the local workstation, so `package_toolbox.m` was
not executed. A File Exchange ZIP upload package was generated from the same
file set the packager uses:

- `language/matlab/build/praxo-core-0.7.0.zip`
- GitHub release asset: <https://github.com/axisvela/praxo-core/releases/download/matlab/v0.7.0/praxo-core-0.7.0.zip>
- Contents: `+praxo/`, `README.md`, `LICENSE`, `toolbox-image.png`
- Size: 132,824 bytes
- SHA-256: `8C45E34DBA9FB9A884DD971BD54AB08A72F9D2247C6206880FE196534E8BC3C1`

The ZIP is the upload artifact. Generate a `.mltbx` in MATLAB when a MATLAB
runtime is available; do not claim MATLAB execution evidence from this ZIP.

## MATLAB File Exchange

The live submission's release/platform labels remain unverified; source changes
do not edit that page. Compatibility must not be broadened from an Octave pass
or packaging alone. See the [registry page evidence requirements](../../docs/languages/registry-pages.md).

1. Sign in at https://www.mathworks.com/matlabcentral/fileexchange/submit
2. Create a submission with:
   - Title: `PRAXO-CORE`
   - Summary: `Embeddable MIT-licensed agent framework for MATLAB`
   - Category: choose the closest AI/agent or MATLAB programming category
   - License: MIT
   - Tags: `agent`, `agent-framework`, `llm`, `ai`, `tool-calling`,
     `openai-compatible`, `memory`, `policy`, `middleware`, `checkpoint`,
     `sandbox`, `mit`
   - Files: upload the `.mltbx` or a ZIP of this directory
3. Add the GitHub URL: https://github.com/axisvela/praxo-core
4. Submit for MathWorks review.

Published entry: <https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core>

Citation:

```text
AxisVela (2026). PRAXO-CORE (Version 0.3.0) [Computer software].
MATLAB Central File Exchange.
https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core
```

MATLAB R2026b requires `UseLicenseBSD` for `.mltbx` files uploaded to File
Exchange. This project is MIT-licensed, so if that requirement blocks the
submission, upload a ZIP of the package instead of the `.mltbx`.

## Octave

The independent Octave Core and its package publication flow live in
[language/octave/PUBLISHING.md](../octave/PUBLISHING.md).
