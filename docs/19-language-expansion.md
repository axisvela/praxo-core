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
| Swift | Core (delivered) | Apple platforms, structured concurrency, `Codable` | Core shipped in `swift/v0.2.0` |
| Julia | Core (delivered) | Scientific computing; JSON/HTTP are available but agent loops are unusual | Core shipped in `julia/v0.2.0` |
| R | Core (delivered) | Statistics and data workflows; package ecosystem is CRAN | Core shipped in `r/v0.2.0` |
| Haskell | Wire | Strong types, smaller AI tooling demand | Wire-level package |
| Fortran | Core | Numeric code; core requires a named consumer | Core SDK with a named consumer |
| Lisp | Bridge | Niche; S-expression/JSON bridge is cheaper than a core port | Only with a named consumer |

## Wave 2 Candidates

These languages are planned but not implemented. The same rules apply: no new
core loop without a named consumer and a maintenance owner.

| Language | Target tier | Rationale | Recommendation |
| --- | --- | --- | --- |
| JavaScript | Sample (TypeScript, delivered) | TypeScript already compiles to JavaScript for Node and browsers | JS sample in `javascript/`; no separate core |
| C++ | Core (delivered) | Native systems and embedding; large surface | Core shipped in `cpp/v0.1.0` |
| Dart | Core (delivered) | Flutter/Dart async, JSON, packaging | Core shipped in `dart/v0.1.0` |
| Ruby | Core (delivered) | Large web integration surface | Core shipped in `ruby/v0.1.0` |
| Kotlin | Sample (JVM) | Consumes the Java SDK | Kotlin sample only; no separate core |
| Scala | Sample (JVM) | Consumes the Java SDK | Scala sample only; no separate core |
| MATLAB | Wire | Scientific workflows; JSON and HTTP available | Wire-level package |
| Perl | Core (delivered) | CPAN, JSON, and HTTP for legacy glue | Core shipped in `perl/v0.1.0` |
| Delphi | Wire / Bridge | Windows enterprise integration | Wire or bridge with a consumer |
| OCaml / Caml | Core | Strong types; niche agent demand | Core SDK with a maintenance owner |
| D | Core (delivered) | Systems language with native JSON and C interop | Core shipped in `d/v0.1.0` |
| Objective-C | Core | Apple platforms; can consume or bridge Swift | Core SDK on Apple platforms |
| Zig | Core (delivered) | Native systems, `std.json`, no runtime | Core shipped in `zig/v0.2.0` |
| Scratch | Bridge / extension | Visual/block environment without native JSON/HTTP | Extension bridge; consumer-gated |
| COBOL | Core | Legacy enterprise batch and process integration | Core SDK with a named consumer |
| Prolog | Bridge | Logic and CLI workflows; no standard HTTP/JSON stack | Bridge with a named consumer |
| ABAP | Bridge | SAP enterprise runtime | Consumer-gated bridge |

JavaScript, Kotlin, and Scala must reuse the TypeScript or Java package rather
than create another contract implementation. Scratch, Prolog, and ABAP do not
justify a native loop.

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
| L3 | Swift core (delivered) | 11 vectors + API snapshot |
| L4 | Julia, R core (delivered); Haskell wire | 11 vectors + API snapshot |
| L5 | Shell bridge; Lisp if consumer | bridge contract tests |
| L6 | C++, Ruby, Perl, Lua, COBOL core; JavaScript, Kotlin, Scala samples | 11 vectors + API snapshot |
| L7 | Dart core; MATLAB wire; Delphi wire/bridge; Scratch, Prolog, ABAP bridges | declared wire or bridge gate |
| L8 | D, Objective-C, OCaml, Zig core; Fortran core with consumer; VBScript bridge | 11 vectors + API snapshot or bridge gate |

Internal effort estimates are tracked outside this repository.

## Not Recommended

- Eleven parallel full implementations.
- Using FFI to embed Go/Rust into every runtime.
- Reimplementing policy/path containment or plugin trust in shell languages.
- Treating Visual Basic as a separate SDK from C#.
- Adding a second JVM core when the Java SDK owns the contract.
- Adding a separate JavaScript core when the TypeScript package is the source.
- Adding Fortran core or Lisp without a named consumer.
- Implementing a native Scratch, Prolog, or ABAP agent loop.

## Decision Log

| ID | Decision | Status |
| --- | --- | --- |
| L1 | Tier the languages; do not write eleven agent loops | accepted |
| L2 | C# is the next native core SDK | accepted |
| L3 | Visual Basic consumes the .NET package; no separate port | accepted |
| L4 | Shell and PowerShell are bridge languages | accepted |
| L5 | Fortran core and Lisp require a named consumer | accepted |
| L6 | Move parity to per-language files as languages grow | proposed |
| L7 | Wave 2 reuses TypeScript for JavaScript and Java for Kotlin/Scala | proposed |
| L8 | C++, Ruby, Perl, Lua, and COBOL target core | proposed |
| L9 | Scratch, Prolog, and ABAP remain consumer-gated bridges | proposed |
| L10 | D, Objective-C, OCaml, and Zig target core; Fortran core needs a consumer | proposed |

## Related Documents

- [Multilingual SDK design](17-multilingual-sdk.md)
- [Multilingual roadmap](18-multilingual-roadmap.md)
- [Compatibility policy](16-compatibility-policy.md)
- [Plugin authoring](10-plugin-authoring.md)
