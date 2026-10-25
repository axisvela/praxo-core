# Multilingual SDK Design

**Status:** design commitment for the `2.x` line, 2026-10-25. This page defines
the shared contract, repository layout, naming rules, and conformance model for
the Python, TypeScript, and Java SDKs. It does not change any exported Go
declaration.

## Why

Go is a good fit for the reference runtime: explicit interfaces, cheap
concurrency, and a small dependency surface. Application teams building agents
mostly work in Python and TypeScript, and enterprise integrators often require
Java. The framework should meet those teams without forking the contract into
three incompatible products.

The goal is **one contract, four idiomatic implementations**:

- Go remains the reference implementation and the source of behavioral truth.
- Python, TypeScript, and Java SDKs implement the same contract.
- A language-neutral specification and conformance suite define "same".
- No SDK depends on another SDK at runtime.

## Non-Goals

- Rewriting or deprecating the Go module.
- Exposing one generated API that looks foreign in every language.
- Shipping provider SDKs, vector databases, or product governance in any SDK.
- Cross-language FFI, shared in-process state, or a polyglot runtime.
- Byte-identical source APIs; only the contract is identical.

## Contract Layers

The contract has four layers. Only the first is wire-identical; the rest are
equivalence requirements.

| Layer | What it covers | Cross-language rule |
| --- | --- | --- |
| Wire | JSON field names and casing, event types, stream kinds, plugin Manifest v1 and host envelopes, error codes, JSON Schema subset | Byte-identical. Renaming is a breaking change |
| Behavior | Agent loop order, fail-closed policy, event order, retry/backoff, token estimation, deterministic compaction, parallel tool ordering | Must pass the same conformance vectors |
| API surface | Interfaces, option fields, result types, middleware boundaries | One-to-one mapping with idiomatic names |
| Conformance | Vectors, fixtures, expected events and errors | One suite, executed by every SDK in CI |

When the specification and the Go implementation disagree, that is a bug. The
specification is normative; Go is the reference implementation used to discover
and validate it.

### Wire Layer

Wire names are frozen as they exist today. The current contract mixes casing:

- `image_url` in `model.ContentBlock` is snake_case.
- `tenantId`, `workspaceId`, `runId`, and `sessionId` are camelCase.
- Event payload keys are documented in [Event schema](event-schema.md).

The multilingual SDKs must preserve this exact mix. Normalizing names in one
SDK is a wire break, even if it looks cleaner.

The wire layer also covers:

- event type strings and stream kinds
- plugin Manifest v1, contract kinds, lifecycle states, process JSON-Lines
  envelopes, and the WASM guest ABI
- error codes and sentinels
- the documented JSON Schema subset and its ignored keywords
- tool-call parsing markers

### Behavior Layer

Behavioral parity is verified through vectors, not prose. Required vector
groups:

| Group | Required assertions |
| --- | --- |
| `agent-loop` | event order, step budget, max tokens, final answer, fail-closed denial |
| `toolcall` | parse, strip markup, malformed input, idempotency passthrough |
| `jsonschema` | accepted/rejected inputs, ignored keywords, Unicode length rules |
| `memory` | frame typing, recall ordering, context assembly |
| `checkpoint` | save/load/list round trip, allowlist behavior |
| `policy` | path containment, denial propagation |
| `stream` | stream kind order and payload shape |
| `plugin` | manifest validation, lifecycle transitions, envelope framing |

Concurrency, cancellation, and error mapping are part of the behavior layer but
are asserted per language with language-specific harnesses that consume the same
fixtures.

### API Surface Layer

The mapping is one-to-one, not name-identical:

| Go | Python | TypeScript | Java |
| --- | --- | --- | --- |
| `model.Model` | `praxo.model.Model` (`Protocol`) | `Model` (`interface`) | `Model` (`interface`) |
| `model.Request` | `praxo.model.Request` (`dataclass`) | `Request` (`interface`) | `Request` (`record`) |
| `agent.Options` | `praxo.agent.Options` (`dataclass`) | `AgentOptions` (`interface`) | `AgentOptions` (`builder`) |
| `agent.New(Options)` | `praxo.agent.Agent(options)` | `new Agent(options)` | `Agent.create(options)` |
| `context.Context` | `contextvars` + task cancellation | `AbortSignal` | cancellation token |
| `error` sentinel | exception class | `Error` subclass | exception class |
| `tool.Tool` | `praxo.tool.Tool` | `Tool` | `Tool` |

Rules:

- Go `Options` fields become optional keyword arguments with identical defaults.
- Go sentinel errors become stable exception classes carrying the same code.
- Go `context.Context` becomes the language's cancellation primitive; it never
  becomes a plain timeout argument.
- Go interfaces become protocols/interfaces with the same method semantics.
- Go concrete adapters are not part of the contract and may differ per language.

### Conformance Layer

`spec/vectors` is the single executable definition of parity. Each SDK provides
a runner and a CI job that executes every vector and fails on the first
behavioral divergence. The Go runner is built first; it proves the vectors are
correct before other languages consume them.

## Source of Truth

```text
spec/                     normative contract and vectors
  SPEC_VERSION            contract version, independent of SDK versions
  parity.md               Go symbol -> Python/TS/Java symbol inventory
  wire/                   JSON envelopes, events, errors, plugin contract
  vectors/                language-neutral behavior fixtures

pkg/                      Go reference implementation (unchanged location)
python/                   Python SDK
typescript/               TypeScript SDK
java/                     Java SDK
```

The Go module stays at the repository root. Moving it under `go/` would break
`go get github.com/axisvela/praxo-core/v2` and every existing import. The new
directories are additive.

Extraction workflow:

1. Read the Go declaration.
2. Write or update the `spec/wire` artifact.
3. Add the `spec/parity.md` row.
4. Add a vector that proves the behavior.
5. Run the Go runner and confirm the vector matches current behavior.
6. Implement the SDK and make the same vector pass.

`spec/parity.md` is checked in. CI verifies that every row is implemented in
every shipped SDK. A missing row or a silent rename fails the build.

## Language Packages

| Language | Distribution | Import root | Minimum runtime |
| --- | --- | --- | --- |
| Go | `github.com/axisvela/praxo-core/v2` | `pkg/...` | Go 1.25 directive |
| Python | `praxo-core` | `praxo` | Python 3.11 |
| TypeScript | `@axisvela/praxo-core` | `@axisvela/praxo-core` and subpaths | Node 20, `ES2022` |
| Java | `io.axisvela:praxo-core` | `io.axisvela.praxo` | Java 21 |

Subpath/package mapping:

| Domain | Python | TypeScript | Java |
| --- | --- | --- | --- |
| model | `praxo.model` | `@axisvela/praxo-core/model` | `io.axisvela.praxo.model` |
| tool | `praxo.tool` | `@axisvela/praxo-core/tool` | `io.axisvela.praxo.tool` |
| event | `praxo.event` | `@axisvela/praxo-core/event` | `io.axisvela.praxo.event` |
| memory | `praxo.memory` | `@axisvela/praxo-core/memory` | `io.axisvela.praxo.memory` |
| policy | `praxo.policy` | `@axisvela/praxo-core/policy` | `io.axisvela.praxo.policy` |
| checkpoint | `praxo.checkpoint` | `@axisvela/praxo-core/checkpoint` | `io.axisvela.praxo.checkpoint` |
| agent | `praxo.agent` | `@axisvela/praxo-core/agent` | `io.axisvela.praxo.agent` |

Optional adapters use separate distributions/artifacts and never enter the core
package.

## Scope Matrix

| Capability | Python | TypeScript | Java | Notes |
| --- | --- | --- | --- | --- |
| Model, tool, event, policy, memory contracts | P1 | P1 | P1 | Required for parity |
| Checkpoint and session contracts | P1 | P1 | P1 | Required for parity |
| Agent loop, budgets, middleware core | P1 | P1 | P1 | Required for parity |
| Streaming projections | P1 | P1 | P1 | Idiomatic async iteration |
| OpenAI-compatible adapter | P1 | P1 | P1 | First adapter in every SDK |
| Anthropic/Gemini adapters | P2 | P2 | P2 | Demand-driven |
| MCP gateway | P2 | P2 | P2 | Demand-driven |
| OTel sink | P2 | P2 | P2 | Demand-driven |
| VFS and local backend | P2 | P2 | P2 | Security-sensitive |
| Scheduler contract | P3 | P3 | P3 | Runtime stays product-owned |
| Process plugin host | P3 | P3 | P3 | Wire contract first |
| WASM plugin host | P4 | P4 | P4 | Language binding differences are large |

P1 is required for a `1.0.0` SDK release. P2 follows adoption. P3/P4 ship only
with a verifiable consumer.

## Compatibility and Versioning

- `spec/SPEC_VERSION` versions the contract, starting at `0.1.0`.
- Each SDK versions independently and declares the supported `SPEC_VERSION`.
- A wire change is breaking for every SDK even if only one SDK ships it.
- A behavioral change requires a vector update and a minor SDK release.
- Adding an optional field or event key is additive.
- Removing or renaming a wire field, event, stream kind, or plugin field is
  breaking and requires a spec major version.
- No SDK may ship a contract feature that the Go reference does not implement.

The Go API freeze in [API freeze inventory](07-api-freeze.md) remains the
reference for the Go surface. The multilingual contract is a projection of that
surface plus documented wire behavior; it does not widen the Go API.

## Security and Licensing

- All SDKs remain MIT.
- Dependencies must be permissive and reviewed before adoption.
- No SDK may import AGPL code.
- Credentials and tenant identifiers stay in adapter configuration.
- Plugin materialization, signature trust, SBOM, and rolling updates remain
  product-owned in every language.
- Path containment and sandbox behavior must be re-verified per language; they
  are not inherited from Go.

## Success Criteria

- One `spec/` tree consumed by four CI jobs.
- `spec/parity.md` has zero gaps for every released SDK.
- The same vectors produce the same events, errors, and loop outcomes.
- A consumer can switch languages without rewriting prompts, tools events, or
  checkpoint data.

## Related Documents

- [Architecture](01-architecture.md)
- [Primitives](02-primitives.md)
- [Multilingual roadmap](18-multilingual-roadmap.md)
- [Compatibility](05-compatibility.md)
- [Compatibility policy](16-compatibility-policy.md)
- [Event schema](event-schema.md)
- [Plugin authoring](10-plugin-authoring.md)
