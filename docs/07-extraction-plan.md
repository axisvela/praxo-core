# PRAXO-CORE Extraction Plan and Framework Spec

**Status:** Authorized for extraction. PRAXOVELA code may be copied directly.

## Goal

Make PRAXO-CORE a LangChain-class framework for governed agents: composable
primitives used by PRAXOVELA and external products.

## Non-Goals

- PRAXOVELA product assembly
- COORDIVELA work graph or coordination policy (COORDIVELA is independent)
- model hosting
- memory storage
- workflow engine
- verification authority
- re-exporting third-party AGPL-only code

## Licensing and Provenance

- PRAXO-CORE is MIT.
- **PRAXOVELA code may be copied directly into PRAXO-CORE** under the user's
  2026-10-18 authorization.
- Each extracted package records source path, source commit, and extraction
  date in `docs/04-license-and-provenance.md` or a package-level `PROVENANCE`.
- No third-party AGPL-only code enters the MIT module.
- PRAXOVELA remains AGPL and may consume the MIT framework.

## Source Mapping

| PRAXOVELA source | PRAXO-CORE target | Risk | Batch |
| --- | --- | --- | --- |
| `packages/axon-core/internal/scheduler` | `pkg/scheduler` | Low | 1 |
| `packages/axon-core/internal/agent/messages.go`, `tool_parse.go` | `pkg/prompt`, `pkg/output` | Low | 1 |
| `packages/axon-core/internal/jsonschema` | `pkg/tool` schema validation | Low | 1 |
| `packages/axon-core/internal/context`, `internal/ctx` | `pkg/flow` context assembly | Medium | 2 |
| `packages/axon-core/internal/memory` | `pkg/memory` adapter helpers | Medium | 2 |
| `packages/axon-core/internal/event` | `pkg/event` sinks/filters | Low | 2 |
| `packages/axon-core/internal/agent` tool APIs | `pkg/tool` middleware | Medium | 2 |
| `packages/axon-core/internal/format` | `pkg/format` code formatters | Low | 3 |
| `packages/axon-core/internal/model`, `internal/provider` | `pkg/model` adapters | High | 3 |
| `packages/axon-core/internal/agent` loop features | `pkg/agent` streaming/retry/callbacks | High | 3 |
| `packages/axon-core/internal/policybridge` | `pkg/policy` adapter | Medium | 3 |
| `packages/axon-core/pkg/sandbox` | `pkg/sandbox` | Medium | 3 |
| `packages/trace`, `internal/event` | `pkg/event` trace sink | Medium | 3 |

## Framework Primitives

### Runnable and Chain

```go
type Runnable[I, O any] interface {
    Invoke(ctx context.Context, input I) (O, error)
}

type Chain[A, B, C any] struct {
    First  Runnable[A, B]
    Second Runnable[B, C]
}
```

Acceptance:

- composition tests
- cancellation propagation
- error short-circuit

### Prompt Template

```go
type Template struct {
    ID        string
    Source    string
    Variables []string
}

func (t Template) Format(vars map[string]string) (string, error)
func (t Template) FormatMessages(vars map[string]string) ([]model.Message, error)
```

Rules:

- missing variables are errors
- no implicit shell/env expansion
- prompt provenance is recorded

### Output Parser

```go
type Parser[T any] interface {
    Parse(raw string) (T, error)
}

type JSONParser[T any] struct{}
type StringParser struct{}
```

Acceptance:

- malformed JSON errors are typed
- parser never silently truncates
- fenced code blocks can be extracted explicitly

### Retriever

```go
type Document struct {
    ID       string
    Content  string
    Metadata map[string]string
    Score    float64
}

type Retriever interface {
    Retrieve(ctx context.Context, query string, limit int) ([]Document, error)
}
```

Adapters:

- Mnemovela
- GNOSIVELA grounding views
- local test retriever

### Scheduler Engine

```go
type Kind string

const (
    KindCron     Kind = "cron"
    KindInterval Kind = "interval"
    KindOnce     Kind = "once"
    KindEvent    Kind = "event"
)

type Schedule struct {
    ID            string
    Kind          Kind
    Expression    string
    Timezone      string
    MisfirePolicy string
    Enabled       bool
    NextRun       time.Time
    LastRun       time.Time
    CreatedAt     time.Time
    Payload       map[string]any
}

type Engine interface {
    Add(ctx context.Context, schedule Schedule) error
    Remove(ctx context.Context, id string) error
    List(ctx context.Context) ([]Schedule, error)
    SetEnabled(ctx context.Context, id string, enabled bool) error
    Start()
    Stop()
}
```

Batch 1 is cron-only; one-shot, interval, event triggers, persistence, and
leases follow in Batch 2/3.

### Tool Schema and Middleware

```go
type Spec struct {
    Name        string
    Description string
    Parameters  map[string]any
    Risk        string
}

type Middleware func(next Tool) Tool
```

Acceptance:

- argument validation
- policy hook before invocation
- event emission after invocation
- timeout and cancellation propagation

### Agent Loop Enhancements

- streaming responses
- retry policy per model/tool
- callback/event sink
- tool-choice control
- max token/step budget
- memory read/write hooks

## Batch Plan

### Batch 1 - Safe Extraction

- `pkg/scheduler` engine (generalized from PRAXOVELA scheduler)
- `pkg/prompt` template
- `pkg/output` parsers
- `pkg/retriever` interface
- `pkg/flow` Runnable/Chain
- tests and provenance records

Exit gate:

- `go test ./...` green
- no AGPL imports
- PRAXOVELA builds without changes
- external consumers can import the batch

### Batch 2 - Agent/Tool/Memory

- tool schema and middleware
- event sinks and filters
- memory context assembler
- scheduler persistence contract
- tests

Exit gate:

- PRAXOVELA adapter shims compile
- no duplicate scheduler implementation

### Batch 3 - Product Adoption

- PRAXOVELA uses framework scheduler/tool/event types
- model/provider adapters move behind framework interfaces
- policy/sandbox adapters
- compatibility tests

Exit gate:

- PRAXOVELA builds against the framework version
- no internal package imports across products
- version ranges documented

### Batch 4 - Stabilization

- API freeze review
- external integrator example
- security review
- 1.0.0 release gate

## Definition of Done

- Framework code is MIT and provenance is recorded.
- Each primitive has unit and conformance tests.
- Consumers build without copying internals.
- Breaking changes are versioned.
- The framework does not own product policy or coordination state.
