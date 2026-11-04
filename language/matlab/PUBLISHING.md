# Publishing the MATLAB/Octave Core

Source tag `matlab/v0.2.1`. The package is not published to Octave Packages or
the MATLAB File Exchange.

Octave verification is not MATLAB verification. Run `run_tests.m` in MATLAB
before submitting to File Exchange.

## Build a MATLAB package

In MATLAB, from this directory:

```matlab
package_toolbox
```

This creates `praxo-core-0.2.1.mltbx` containing `+praxo`, `README.md`,
`LICENSE`, `run_tests.m`, and `toolbox-image.png`. The image is
`language/matlab/toolbox-image.png`; use it as the File Exchange thumbnail.

MATLAB package names must be identifiers matching `[A-Za-z][A-Za-z0-9_]*`.
Use `praxo_core` as the package name; keep `PRAXO-CORE` only as the display
name. `package_toolbox.m` sets both accordingly.

## MATLAB File Exchange

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

MATLAB R2026b requires `UseLicenseBSD` for `.mltbx` files uploaded to File
Exchange. This project is MIT-licensed, so if that requirement blocks the
submission, upload a ZIP of the package instead of the `.mltbx`.

## Octave Packages

For Octave Packages, add package metadata and package the `+praxo` directory,
then open a pull request to <https://github.com/gnu-octave/packages>. No separate
account is required.
