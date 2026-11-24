# Runtime-Aligned Tutorial Design

These are tutorial designs, not new Core features or additional members of the
100-scenario catalog. Prefer common language ecosystems and existing host shapes
over arbitrary industry assignments. Existing tutorial URLs remain valid.

## Scenario Selection

| Language | Primary tutorial direction | Related goal | Ecosystem basis | Required behavior | Initial status |
| --- | --- | --- | --- | --- | --- |
| V | [Local configuration and release preflight](https://github.com/axisvela/praxo-core/tree/main/language/v/Tutorial/release-preflight) | SE-01 | Compiled CLI tools and C interoperability; exploratory ecosystem, not established industry leadership | Parse temporary configuration, reject missing fields, draft corrections; no deployment | Local V checks passed; remote CI unverified |
| D | [Data-import pipeline diagnosis](https://github.com/axisvela/praxo-core/tree/main/language/d/Tutorial/data-pipeline) | SC-06 | Native data processing, standard-library ranges/algorithms and C interoperability | Parse records, calculate invalid counts and field errors, select a review action from results | Local DMD checks passed; remote CI unverified |
| Haskell | [Business-rule DSL validation](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial/rule-dsl) | SE-05 | Typed ASTs, parser libraries, pure evaluation and property testing | Parse rules, detect a conflict and return a counterexample; no rule publication | Local GHC checks passed; remote CI unverified |
| OCaml | [Static-analysis diagnostic review](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/static-diagnostics) | SE-05 | Compilers, typed syntax trees and analyzers | Parse structured diagnostics or a small AST and evaluate rules with source locations | Local OCaml checks passed; remote CI unverified |
| Erlang | [OTP service recovery review](https://github.com/axisvela/praxo-core/tree/main/language/erlang/Tutorial/otp-recovery) | SE-06 | Telecom, messaging, process isolation and supervision | Start a supervision tree, crash one child and observe recovery before drafting | Local OTP checks passed; remote CI unverified |
| Julia | Constrained energy-dispatch review | IN-04 | Numerical computing and JuMP optimization ecosystem | Solve a small constrained model, report feasibility and objective; no grid commands | Planned |
| Octave | Vibration-signal inspection review | IN-01 | Matrix operations, FFT and MATLAB-style engineering analysis | Calculate FFT/RMS for normal and anomalous samples; no failure prediction | Planned |
| COBOL | End-of-day reconciliation exception review | FC-03 | Decimal business records and banking/insurance batch estates | Calculate reconciliation differences in COBOL, review exception records without changing the ledger | Planned enhancement of batch-exception-review |
| Zig | C ABI host-health diagnostic component | IN-01 | Explicit allocators, native components and C ABI | Read actual C callback state, test an allocation budget and cleanup; no hardware commands | Planned enhancement of gateway-health |

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
