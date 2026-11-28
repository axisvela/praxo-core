# Runtime-Aligned Tutorial Design

These are tutorial designs, not new Core features or additional members of the
100-scenario catalog. Prefer common language ecosystems and existing host shapes
over arbitrary industry assignments. Existing tutorial URLs remain valid.

## Scenario Selection

**CI update: 2026-11-25.** All nine paths below passed their tutorial jobs at
`dfdfd558` in [run 45537631891](https://github.com/axisvela/praxo-core/actions/runs/45537631891).
The final column preserves the initial local snapshot: its "remote CI unverified"
notes describe that earlier snapshot, not current CI. Hosted execution does not
establish live-provider, hardware, production or independent adoption evidence.
These bounded paths are reusable inputs to the
[reference application portfolio](../project/delivery-history.md#reference-application-portfolio),
not substitutes for full host integration.

| Language | Primary tutorial direction | Related goal | Ecosystem basis | Required behavior | Initial local snapshot (superseded for CI above) |
| --- | --- | --- | --- | --- | --- |
| V | [Local configuration and release preflight](https://github.com/axisvela/praxo-core/tree/main/language/v/Tutorial/release-preflight) | SE-01 | Compiled CLI tools and C interoperability; exploratory ecosystem, not established industry leadership | Parse temporary configuration, reject missing fields, draft corrections; no deployment | Local V checks passed; remote CI unverified |
| D | [Data-import pipeline diagnosis](https://github.com/axisvela/praxo-core/tree/main/language/d/Tutorial/data-pipeline) | SC-06 | Native data processing, standard-library ranges/algorithms and C interoperability | Parse records, calculate invalid counts and field errors, select a review action from results | Local DMD checks passed; remote CI unverified |
| Haskell | [Business-rule DSL validation](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial/rule-dsl) | SE-05 | Typed ASTs, parser libraries, pure evaluation and property testing | Parse rules, detect a conflict and return a counterexample; no rule publication | Local GHC checks passed; remote CI unverified |
| OCaml | [Static-analysis diagnostic review](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/static-diagnostics) | SE-05 | Compilers, typed syntax trees and analyzers | Parse structured diagnostics or a small AST and evaluate rules with source locations | Local OCaml checks passed; remote CI unverified |
| Erlang | [OTP service recovery review](https://github.com/axisvela/praxo-core/tree/main/language/erlang/Tutorial/otp-recovery) | SE-06 | Telecom, messaging, process isolation and supervision | Start a supervision tree, crash one child and observe recovery before drafting | Local OTP checks passed; remote CI unverified |
| Julia | [Constrained energy-dispatch review](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/dispatch-review) | IN-04 | Numerical computing; native bounded enumeration today, JuMP ecosystem not yet used | Solve a small constrained model, report feasibility and objective; no grid commands | Local Julia checks passed; remote CI unverified |
| Octave | [Vibration-signal inspection review](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/vibration-review) | IN-01 | Matrix operations, FFT and MATLAB-style engineering analysis | Calculate FFT/RMS for normal and anomalous samples; no failure prediction | Local Octave checks passed; remote CI unverified |
| COBOL | [End-of-day reconciliation exception review](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review) | FC-03 | Decimal business records and banking/insurance batch estates | Calculate reconciliation differences in COBOL, review exception records without changing the ledger | Local GnuCOBOL checks passed; remote CI unverified; fixed-width fixture only |
| Zig | [C ABI host-health diagnostic component](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health) | IN-01 | Explicit allocators, native components and C ABI | Read actual function-table state, exercise a fixed allocation budget and cleanup; no hardware commands | Local Zig checks passed; remote CI unverified; fixed-budget scratch allocation, not a general allocator policy |

Related goals express discovery relevance, not full implementation or blanket
language recommendations. V and Zig are host/toolchain choices; they must not be
marketed as widely adopted industry platforms. A custom Julia enumeration is not
JuMP evidence, and an Erlang escript alone is not supervision evidence.

## Teaching Contract

Each tutorial uses a bounded local fixture with real parsing, calculation or
runtime behavior, then gives the result to Core tools. The deterministic Agent
must choose its next action from the tool result, not always draft success.
Credential-free checks cover success, malformed or infeasible input, scope denial
before effects, and dependency failure without a later draft. A live model can use
the same tools as an optional, separately recorded check.

## Implementation Sequence

Start with D record parsing, then V preflight, Haskell rule validation, OCaml
diagnostics, Erlang supervision, Julia optimization and Octave signal analysis.
Extend the existing COBOL and Zig paths rather than copying their hosts.
Publish a tutorial only after its own checks run; design approval is not runtime
evidence. Record toolchain limitations without treating them as product behavior.

Keep this design linked from the tutorial plan and per-language introduction.
Add each implemented path to the generated catalog and tutorial CI. Do not alter
Core APIs or normative wire contracts for application-specific business logic.
