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
- Size: 165,853 bytes
- SHA-256: `7356B31955AF3EA3338BF185539E6681DA77C6405C7F2FCCE67EDC856CF8A63D`

The ZIP is the upload artifact. Generate a `.mltbx` in MATLAB when a MATLAB
runtime is available; do not claim MATLAB execution evidence from this ZIP.

## File Exchange Submission Text

File Exchange shows the submission Description, not the repository README or
the README inside the ZIP. Source changes do not update the visible page; a
MathWorks account must edit submission 185166 and upload the current ZIP. Use
the following text in the submission Description field:

```text
PRAXO-CORE is an MIT-licensed embeddable agent framework for MATLAB. It provides
a native agent loop, tool contracts, policy hooks, memory, checkpoints, context
compaction, events, middleware, HITL decisions, MCP-shaped transport for a
caller-owned client, OpenAI/Anthropic/Gemini adapters, Harmovela and OTel event
sinks, retrieval, and synchronous subagent delegation.

Install from File Exchange, or download the source release ZIP and add the
installed toolbox to the MATLAB path:
https://github.com/axisvela/praxo-core/releases/download/matlab/v0.9.0/praxo-core-0.9.0.zip

Quickstart:
  result = praxo.agent_run('Hi', @(request) struct('content', 'hello'), {}, struct());
  disp(result.output)

Examples (15 runnable examples bundled):
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
- representative-chain: MCP, delegation, OTel/Harmovela, and denied edit
- advanced-delegation: parent/child scope and six governance checks
Examples source and commands:
https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples

Scenario tutorials (bundled under Tutorial/):
- data-quality: fixed mean/median/outlier statistics; Core chooses normal or
  outlier review without modifying source data.
- signal-trends: one fixed review_signal tool computes bounded metrics and
  returns a review-only report with no device control.
Tutorials source:
https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial

Reference applications:
No accepted end-to-end reference application is recorded for MATLAB yet.
Candidate goals are tracked in:
https://axisvela.github.io/praxo-core/project/planning/roadmap/#reference-application-portfolio

Planning context:
- Tutorial plan:
  https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/
- 100 candidate agent scenarios:
  https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/
- Unified Tutorial Catalog:
  https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/

Documentation:
https://axisvela.github.io/praxo-core/languages/matlab/

Community:
- GitHub Discussions: https://github.com/axisvela/praxo-core/discussions
- GitHub Issues: https://github.com/axisvela/praxo-core/issues
- X: https://x.com/axisvela
- Weibo: https://weibo.com/u/1936025761
- LinkedIn: https://www.linkedin.com/company/axisvela/
- Facebook: https://www.facebook.com/profile.php?id=61596905732406
- YouTube: https://www.youtube.com/@axisvela
- Discord: https://discord.com/channels/1575163993767809064/1575164343148875977
- Documentation: https://axisvela.github.io/praxo-core/
- Architect: https://axisvela.architect.pub

Limits: MATLAB runtime compatibility is unverified; current execution evidence
is GNU Octave 11.3.0. The examples and tutorials are bundled in the File Exchange
package. Commercial MATLAB releases, MATLAB Online, and OS-specific support are
not claimed.
```

The live File Exchange Description is a separate submission field. Source
changes and new ZIP uploads do not update it; edit the submission Description
with the text above, then save or resubmit for review.

## MATLAB File Exchange

The live submission's release/platform labels remain unverified; source changes
do not edit that page. Compatibility must not be broadened from an Octave pass
or packaging alone. See the [registry page evidence requirements](../../docs/languages/registry-pages.md).

1. Sign in at https://www.mathworks.com/matlabcentral/fileexchange/submit
2. Create or edit the submission with:
   - Title: `PRAXO-CORE`
   - Summary: `Embeddable MIT-licensed agent framework for MATLAB`
   - Category: choose the closest AI/agent or MATLAB programming category
   - License: MIT
   - Tags: `agent`, `agent-framework`, `llm`, `ai`, `tool-calling`,
     `openai-compatible`, `memory`, `policy`, `middleware`, `checkpoint`,
     `sandbox`, `mit`
   - Files: upload the `.mltbx` or the current ZIP
   - Description: paste the submission text above
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
