# Workspace and Session Contract (Evaluation)

**Status:** evaluation draft, 2026-10-24. This page is not an API commitment. It
records the problem, candidate shape, provider questions, and the criteria for
promoting a contract into `pkg/`.

## Why Evaluate This

PRAXO-CORE currently separates two seams:

| Seam | Contract | Current use |
| --- | --- | --- |
| Virtual filesystem | `vfs.Backend` | Read, write, list, glob, grep, delete |
| Command execution | `vfs.Executor` | Optional shell execution on a VFS backend |
| Sandbox | `sandbox.Sandbox` | One `Run(ctx, Spec, command)` call |
| Interpreter | `sandbox.Interpreter` | Optional in-process script evaluation |

That is enough for stateless execution and local workspaces. Remote sandbox
services such as E2B, OpenSandbox, or CubeSandbox add a lifecycle:

```text
create or attach -> execute -> upload/download -> pause/resume -> close
```

Deep Agents models this as a pluggable backend protocol, with a sandbox backend
that adds execution. PRAXO-CORE should learn from that shape without copying
LangGraph state, a graph runtime, or a provider SDK.

The gap is not "more sandbox providers". The gap is a provider-neutral session
contract that can be verified against at least two implementations.

## Requirements

1. **Stateful lifecycle.** Create or attach to a session, run multiple commands,
   transfer files, and close it. Pause, resume, and snapshot are optional
   capabilities, not required methods.
2. **Composition over duplication.** A session should expose the existing
   `sandbox.Sandbox` and `vfs.Backend` behavior without redefining them.
3. **No provider leakage.** The public contract contains no E2B, OpenSandbox, or
   CubeSandbox types, credentials, endpoints, or control-plane fields.
4. **Caller-owned auth and tenancy.** Products pass credentials and tenant
   context through adapter configuration, never the core contract.
5. **Context and timeouts.** Every operation accepts `context.Context`; timeout
   and cancellation are observable and do not leak sessions.
6. **Error mapping.** Missing sessions, unsupported capabilities, policy
   failures, and provider errors are distinguishable.
7. **No control plane.** Pooling, image catalogs, snapshots, network policy,
   quotas, billing, multi-tenant isolation, audit, and SLAs are product-owned.
8. **Conformance.** A shared check suite must run against fakes and at least two
   live providers before promotion.

## Candidate Shape

The following is a design sketch, not an exported API.

```go
package workspace

type Spec struct {
    Image     string
    WorkDir   string
    Env       map[string]string
    Timeout   time.Duration
    Metadata  map[string]string
}

type Session interface {
    ID() string
    sandbox.Sandbox
    vfs.Backend
    Upload(ctx context.Context, path string, data []byte) error
    Download(ctx context.Context, path string) ([]byte, error)
    Close(ctx context.Context) error
}

type Provider interface {
    Create(ctx context.Context, spec Spec) (Session, error)
    Attach(ctx context.Context, id string) (Session, error)
}

type Pauser interface {
    Pause(ctx context.Context) error
    Resume(ctx context.Context) error
}
```

Alternatives to evaluate:

- **Embedding vs composition.** Embedding `sandbox.Sandbox` and `vfs.Backend` is
  convenient but forces every session to support both. Returning `Files()`
  and `Sandbox()` accessors is more flexible but less ergonomic.
- **Optional capabilities.** Pause/resume should be a separate interface, not a
  method that fails at runtime. The same applies to snapshots and port access.
- **Session identity.** Decide whether `ID()` is provider-local, globally unique,
  or opaque. Products must not parse it.
- **Attach semantics.** Attach may be unsupported, may require the same caller
  identity, or may resume a paused session. These are different capabilities.
- **File transfer.** Upload/download may be required for providers whose VFS
  operations are expensive or asynchronous. Do not assume they are cheap.
- **Resource and network policy.** Keep them in adapter configuration until two
  providers show a stable common subset.

## Provider Evaluation

This table is a checklist, not a claim about current provider behavior or
licensing. Fill it from upstream documentation and adapter spikes.

| Question | E2B | OpenSandbox | CubeSandbox |
| --- | --- | --- | --- |
| Go SDK or stable HTTP API | TBD | TBD | TBD |
| Create / attach / close | TBD | TBD | TBD |
| Repeated command execution | TBD | TBD | TBD |
| Upload / download | TBD | TBD | TBD |
| Pause / resume | TBD | TBD | TBD |
| Snapshot or template | TBD | TBD | TBD |
| Network and port policy | TBD | TBD | TBD |
| Timeout and cancellation | TBD | TBD | TBD |
| Error taxonomy | TBD | TBD | TBD |
| Auth and tenancy model | TBD | TBD | TBD |
| License compatibility | TBD | TBD | TBD |
| Control-plane features | TBD | TBD | TBD |

The adapter spike must record the tested version, endpoint type, license, and
which capabilities are unavailable.

## Prototype Plan

1. Add two adapter modules outside the core, for example
   `adapters/workspace/e2b` and `adapters/workspace/opensandbox`. Keep each in
   its own `go.mod` and tag it independently.
2. Implement create/attach, execute, upload/download, and close against a
   caller-supplied credential. Do not add a provider SDK to the core module.
3. Add an in-memory fake that implements the same contract for offline tests.
4. Run one shared conformance suite against the fake and both adapters. Live
   provider tests are opt-in and must not run in default CI.
5. Record every capability that does not fit, every provider-specific field, and
   every error that cannot be mapped cleanly.
6. Only then propose an additive `pkg/` contract. The existing `pkg/vfs` and
   `pkg/sandbox` declarations remain unchanged.

## Promotion Criteria

A workspace/session contract is ready for `pkg/` only when:

- two providers implement it without provider-specific fields in the public
  contract;
- the fake and both adapters pass the same conformance checks;
- cancellation and timeout do not leak sessions;
- error mapping is documented and tested;
- the core module still has no provider SDK dependency;
- the API is additive and does not change `vfs.Backend`, `vfs.Executor`, or
  `sandbox.Sandbox`;
- the compatibility and migration notes are written.

Until then, the contract stays in an adapter or evaluation module. The current
spike lives in
[`adapters/workspace`](https://github.com/axisvela/praxo-core/tree/main/adapters/workspace)
and provides the candidate contract, an in-memory fake, conformance checks, and
offline E2B and Daytona adapters. Neither adapter has been verified against a
live provider in this environment.

## Non-Goals

- A sandbox control plane, scheduler, warm pool, image registry, or billing
  system.
- A graph runtime or durable workflow engine.
- Provider-specific fields in `pkg/...`.
- A claim that a sandbox interface provides OS-level isolation. Isolation is
  provided by the provider or product.

## Open Questions

- Should `Session` embed both `vfs.Backend` and `sandbox.Sandbox`, or expose them
  as accessors?
- Is `Attach` a core lifecycle operation or a provider capability?
- Should pause/resume/snapshot share one optional capability interface?
- How are provider-side session IDs scoped across tenants and regions?
- What is the minimum portable error taxonomy?
- Which file-transfer semantics are safe to standardize: overwrite, atomic
  write, directory upload, or none?
- Does a workspace session need a lease or heartbeat, or is that product-owned?

## References

- [Deep Agents backends](https://docs.langchain.com/oss/python/deepagents/backends)
- [Sandbox seam security boundary](08-security.md)
- [Containment review](containment-review.md)
- [Event schema](event-schema.md)
