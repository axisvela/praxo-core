# Publishing the MATLAB/Octave Core

Source tag `matlab/v0.9.0`. The package is published on MATLAB File Exchange:
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

This creates `praxo-core-0.9.0.mltbx` containing `+praxo`, `examples/`, `Tutorial/`, `README.md`,
`LICENSE`, and `toolbox-image.png`. The image is
`language/matlab/toolbox-image.png`; use it as the File Exchange thumbnail.

MATLAB package names must be identifiers matching `[A-Za-z][A-Za-z0-9_]*`.
Use `praxo_core` as the package name; keep `PRAXO-CORE` only as the display
name. `package_toolbox.m` sets both accordingly.

## Generated Upload ZIP (2026-11-26)

MATLAB is not installed on the local workstation, so `package_toolbox.m` was
not executed. A File Exchange ZIP upload package was generated from the same
file set the packager uses:

- `language/matlab/build/praxo-core-0.9.0.zip`
- GitHub release asset: <https://github.com/axisvela/praxo-core/releases/download/matlab/v0.9.0/praxo-core-0.9.0.zip>
- Contents: `+praxo/`, `examples/`, `Tutorial/`, `README.md`, `LICENSE`, `toolbox-image.png`
- Size: 165,609 bytes
- SHA-256: `03911D6DD58BA722E38E9FDF1C3D061FF57FB52EC2A77C8E583200137D28C609`

The ZIP is the upload artifact. Generate a `.mltbx` in MATLAB when a MATLAB
runtime is available; do not claim MATLAB execution evidence from this ZIP.

## File Exchange Submission Text

File Exchange shows the submission description, not the repository README or
the README inside the ZIP. Use the following text in the submission Description
field when uploading `praxo-core-0.9.0.zip`:

```text
PRAXO-CORE is an MIT-licensed embeddable agent framework for MATLAB. It provides
a native agent loop, tool contracts, policy hooks, memory, checkpoints, context
compaction, events, middleware, HITL decisions, MCP-shaped transport for a
caller-owned client, OpenAI/Anthropic/Gemini adapters, Harmovela and OTel event
sinks, retrieval, and synchronous subagent delegation.

Install from File Exchange, or download the 0.9.0 ZIP from
https://github.com/axisvela/praxo-core/releases/download/matlab/v0.9.0/praxo-core-0.9.0.zip
and add the installed toolbox to the MATLAB path.

Quickstart:
  result = praxo.agent_run('Hi', @(request) struct('content', 'hello'), {}, struct());
  disp(result.output)

Examples (15 runnable examples plus two tutorials are bundled):
- consumer: deterministic model, tool, and allow/deny
- live-model: OpenAI-compatible endpoint and get_time tool
- service: transport-neutral HTTP handler
- identity-policy: trusted principal and tenant checks
- structured-output: schema validation and rejection
- streaming: accumulated output reconstruction
- retry: bounded transient retry
- provider-fallback: primary failure and fallback
- checkpoint: allowlist round trip
- session-checkpoint: multi-turn history recovery
- event-sink: filtered sink composition
- mcp: caller-owned MCP-shaped transport
- hitl: approve, edit, reject, and respond

Example source and commands:
https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples

Tutorial plan:
https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/

100 candidate agent scenarios:
https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/

Unified Tutorial Catalog:
https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/

Reference application portfolio:
https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio

Documentation:
https://axisvela.github.io/praxo-core/languages/matlab/

Limits: MATLAB runtime compatibility is unverified; current execution evidence
is GNU Octave 11.3.0. The examples and tutorials are bundled in the File Exchange
package. Commercial MATLAB releases, MATLAB Online, and OS-specific support are
not claimed.
```

The current live File Exchange page is version 0.5.0 and will not change until
a MathWorks account uploads the 0.9.0 ZIP and updates the Description field.
Uploading the ZIP alone may leave the visible description unchanged.

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
