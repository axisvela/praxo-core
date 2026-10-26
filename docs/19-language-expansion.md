# Language Expansion Plan

**Status:** planning, 2026-10-25. This page evaluates C#, Shell, PowerShell,
Visual Basic, R, PHP, Swift, Fortran, Lisp, Julia, and Haskell. It does not add
new SDKs. C and Rust are tracked separately in
[Multilingual roadmap](18-multilingual-roadmap.md).

Canonical per-language status lives in `spec/languages.md`.

## Decision

Do not hand-write eleven more full agent loops. The contract is already
proven by five implementations: Go, Python, TypeScript, Java, and Rust. The next
step is a **tiered language strategy**:

- **Native core SDKs** where the ecosystem can carry the full contract.
- **Wire-level SDKs** for languages that need to produce or consume the
  contract but should not own an agent loop.
- **Bridge bindings** for shells, Visual Basic, and legacy languages that
  should call a maintained runtime through a stable process boundary.

This keeps one normative contract and avoids eleven divergent agent loops.

## Tier Model

| Tier | What it implements | Agent loop | Contract gate |
| --- | --- | --- | --- |
| Core | Full SDK: model, tool, event, policy, memory, checkpoint, context, middleware, agent | Yes | All 11 vector groups |
| Wire | Serialization, toolcall, JSON Schema, plugin manifest, events, checkpoint envelopes | No | Wire + subset vectors |
| Bridge | CLI/stdio or HTTP client over a core runtime | Delegated | Bridge contract tests |
| Sample | Language-specific usage of another SDK (for example VB.NET over C#) | No | Compiles against the .NET package |

A language may ship more than one tier over time. For example, a Shell wrapper
is bridge-only, while PHP can start wire-only and later grow a core loop.

## Language Matrix

| Language | Target tier | Rationale | Recommendation |
| --- | --- | --- | --- |
| C# | Core (.NET) | Strong agent/tooling ecosystem, async, JSON, good packaging | Next native SDK after C |
| Visual Basic | Sample (.NET) | Same runtime and assemblies as C# | Ship VB samples, not a second implementation |
| PowerShell | Bridge | Automation and operator glue; not a runtime host | Wrap the .NET CLI or a core CLI |
| Shell | Bridge | POSIX/Bash glue; unsafe for policy, JSON, and plugin hosts | Wrap a CLI over stdio/JSON |
| PHP | Core (delivered) | Large web integration surface; synchronous ecosystem | Core shipped in `php/v0.1.0` |
| Swift | Wire (delivered) | Apple platforms, structured concurrency, `Codable` | Wire shipped in `swift/v0.1.0`; core later |
| Julia | Wire | Scientific computing; JSON/HTTP are available but agent loops are unusual | Wire-level package |
| R | Wire | Statistics and data workflows; package ecosystem is CRAN | Wire-level package |
| Haskell | Wire | Strong types, smaller AI tooling demand | Wire-level package |
| Fortran | Bridge | Numeric code; no practical agent runtime | Only with a named consumer |
| Lisp | Bridge | Niche; S-expression/JSON bridge is cheaper than a core port | Only with a named consumer |

## .NET Unification

C#, Visual Basic, and PowerShell can share one .NET implementation:

- `csharp/` (or `dotnet/`) publishes `AxisVela.Praxo.Core`.
- VB.NET consumes the same package; add samples and API notes, not a fork.
- PowerShell wraps a CLI entry point or loads the .NET assembly.
- Target `net8.0` and keep the public surface CLS-compliant where practical.

This avoids three separate implementations for one runtime.

## Bridge Contract

Bridge languages must not reimplement the agent loop. Define a small,
versioned process contract:

```text
praxo run --session <id> --prompt <text> --json
praxo tool list --json
praxo event stream --json-lines
```

Rules:

- JSON on stdout, diagnostics on stderr.
- One JSON object per line for streams.
- Errors use the shared error codes from `spec/wire/errors.json`.
- The bridge declares the `SPEC_VERSION` it targets.
- Shell/PowerShell wrappers must not parse or rewrite tool-call markup unless
  the bridge contract exposes it.

This is intentionally a **process boundary**, not FFI. It keeps the MIT
framework boundary and avoids ABI/GC/threading coupling.

## Parity and Vectors

The current `spec/parity.md` table is sized for core SDKs. With more languages,
a single wide table stops scaling.

Planned structure:

```text
spec/
  languages.md               tier and status per language
  parity.md                  existing core-language inventory
  parity/
    csharp.md
    php.md
    swift.md
    julia.md
    r.md
    haskell.md
    bridge-shell.md
    bridge-powershell.md
```

Rules:

- A core SDK implements all 11 vector groups.
- A wire SDK implements the wire and subset vectors it declares.
- A bridge implements the bridge contract and error-code mapping.
- A sample is not a contract implementation and has no parity file.
- The parity linter reads `spec/languages.md` and only enforces declared scope.

## Tags

| Artifact | Tag shape |
| --- | --- |
| C# | `csharp/v0.1.0` |
| PHP | `php/v0.1.0` |
| Swift | `swift/v0.1.0` |
| Julia | `julia/v0.1.0` |
| R | `r/v0.1.0` |
| Haskell | `haskell/v0.1.0` |
| Shell bridge | `shell/v0.1.0` |
| PowerShell bridge | `powershell/v0.1.0` |
| VB.NET sample | no tag; ships with the .NET package |
| Fortran/Lisp | tag only if a consumer is named |

## Phases

| Phase | Scope | Exit gate |
| --- | --- | --- |
| L0 | Stabilize Go/Python/TS/Java/Rust; finish C via toolchain or CI | existing gates green |
| L1 | .NET core (C#), VB samples, PowerShell bridge | 11 vectors + .NET API snapshot |
| L2 | PHP core (delivered) | 11 vectors + API snapshot |
| L3 | Swift core | 11 vectors + API snapshot |
| L4 | Julia, R, Haskell wire | declared wire vectors |
| L5 | Shell bridge, Fortran/Lisp if consumer | bridge contract tests |

## Effort

Rough order of magnitude for a full core SDK:

| Language | Core estimate | Wire estimate |
| --- | --- | --- |
| C# | 8-12 weeks | 2-3 weeks |
| PHP | 8-12 weeks | 2-3 weeks |
| Swift | 8-12 weeks | 2-3 weeks |
| Julia | 6-10 weeks | 2 weeks |
| R | 6-10 weeks | 2 weeks |
| Haskell | 8-12 weeks | 2-3 weeks |
| Shell/PowerShell | bridge only | 1-2 weeks |
| Fortran/Lisp | bridge only | 1-2 weeks with consumer |

These assume one engineer per language and reuse of the existing vectors. They
are not commitments.

## Not Recommended

- Eleven parallel full implementations.
- Using FFI to embed Go/Rust into every runtime.
- Reimplementing policy/path containment or plugin trust in shell languages.
- Treating Visual Basic as a separate SDK from C#.
- Adding Fortran/Lisp without a named consumer.

## Decision Log

| ID | Decision | Status |
| --- | --- | --- |
| L1 | Tier the languages; do not write eleven agent loops | accepted |
| L2 | C# is the next native core SDK | accepted |
| L3 | Visual Basic consumes the .NET package; no separate port | accepted |
| L4 | Shell and PowerShell are bridge languages | accepted |
| L5 | Fortran and Lisp require a named consumer | accepted |
| L6 | Move parity to per-language files as languages grow | proposed |

## Related Documents

- [Multilingual SDK design](17-multilingual-sdk.md)
- [Multilingual roadmap](18-multilingual-roadmap.md)
- [Compatibility policy](16-compatibility-policy.md)
- [Plugin authoring](10-plugin-authoring.md)
