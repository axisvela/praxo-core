# Embedding and Execution Profiles

**Design status: 2026-11-06.** One Agent Execution Kernel, one Core version line,
and three integration levels. These are not three kernels, distributions,
constructor flags, or new public APIs. This design changes no default behavior,
wire schema, or language support promise.

Independent SDK and adapter versions remain unchanged; no profile-specific
release line is created.

| Level | Current status | Selection |
| --- | --- | --- |
| Standard Embedding | Existing embedding behavior | Embed the loop and configure the controls your application needs |
| Governed Execution Profile | Proposed acceptance design; partial integration evidence | Require explicit authorization, operation binding and failure handling |
| Embodied Integration Profile | Proposed design; consumer pilot not started | Add remote-action and observation requirements for a named embodied consumer |

The Go reference is the behavioral starting point. Other language implementations
must declare their own supported controls and evidence; the same level name does
not establish language parity. See [Contract and Evidence Status](../project/contract-status.md).

## Standard Embedding

Standard Embedding names the existing ordinary embedding model, not a new
certified profile. Applications use the existing Agent/model/tool interfaces,
configure budgets and optional controls, and own deployment and external effects.

| Core implements | Tests verify | Consumer supplies |
| --- | --- | --- |
| Local model/tool loop, configured policy/HITL, events and cancellation | Declared unit/vector behavior and published-package consumer fixtures | Model adapters, tool implementations, credentials and task-specific controls |
| Session/checkpoint and sandbox contracts | Serialization, resume/adapter behavior in the named tests | Durable storage, effect reconciliation and actual execution isolation |

A Go Agent can omit Policy; this is not an implicit fail-closed security mode.
An empty `AllowedTools` currently means unrestricted, not deny-all. Standard
Embedding can use strong controls, but their presence does not automatically
satisfy the full Governed Execution Profile. Optional does not mean unnecessary
for a particular application's risk.

Start with the [consumer starters](../getting-started/index.md) and
[adoption guide](../getting-started/adoption.md). Pin the actual package version
and keep deterministic allow/deny tests when connecting a real provider.

## Governed Execution Profile

This is an integration acceptance contract layered on Standard Embedding, not a
separate loop. Its proposed obligations are detailed in
[Governed Execution Profile](governed-execution.md): mandatory policy and explicit
scope, trusted caller/resource binding, final-operation authorization and approval
binding, required-dependency failure handling, context trust, and effect recovery.

Enforcement is split deliberately. Core executes configured hooks and lifecycle
checks; the consumer rejects missing mandatory configuration and supplies identity
verification, durable approvals/evidence where required, isolated execution and
authoritative business-state queries. A policy hook cannot constrain malicious
same-process code. Required evidence failures must follow a defined policy; a
failure after business commit must not trigger blind re-execution.

Published-package governed tests and identity/long-running recipes establish only
their stated assertions. They do not establish general profile implementation,
authentic production identity, persistent approvals, or complete deployment
security. No `Profile: Governed` switch or certification is provided.

## Embodied Integration Profile

This proposed domain integration adds obligations to the governed acceptance
contract; it does not replace or weaken them. The
[Embodied Integration Profile](embodied-integration.md) defines remote submission,
feedback, observation freshness, cancellation confirmation and effect verification.
It requires a named consumer, one middleware and a simulation scenario before
being described as an experimental implementation.

A tool can call a robot service today without satisfying this proposed profile.
Neither that call nor a simulation pass establishes hardware safety, real-time
control, certified isolation or emergency-stop behavior.

## Selection and Composition

| Requirement | Starting point |
| --- | --- |
| Local assistant or deterministic tool-loop prototype | Standard Embedding; choose controls explicitly |
| Protected enterprise tools or tenant-sensitive operations | Governed acceptance design plus consumer-owned enforcement/evidence |
| Robot or embodied service integration | Governed obligations plus the embodied design and a bounded consumer pilot |
| Durable distributed workflows or safety controller | An external workflow/execution/safety authority; none of these levels supplies it |

These levels are not mutually exclusive runtime modes or a security score.
Selecting a stronger label does not create external controls. State missing
requirements and unsupported capabilities rather than silently falling back to
Standard Embedding. Keep the ordinary embedding path available.

## Claims and Compatibility

The proposed [Execution Correctness Suite](../project/execution-correctness.md)
defines failure-boundary acceptance across EC-D, EC-I and EC-O tracks. It is an
inventory, not evidence that either profile is implemented or has passed.

For a scoped integration evaluation, record the level/design revision, package
versions and artifact hashes, consumer scenario, enforcing component for each
requirement, configuration, actual tests/results and remaining gaps. Distinguish
implemented controls, fixtures, proposed controls and unverified deployment
properties. This is an evidence description, not a new wire format or certificate.

`agent.Profile` remains a bundle of default options. `model.ProviderProfile`
describes model capabilities, and workspace runtime profiles describe adapter
capabilities. None is an execution-profile attestation or automatic enforcement.

Prefer existing seams. Any future shared API/wire promotion requires a named
consumer, negative tests, compatibility review, normative `spec/` updates when
applicable, parity/conformance checks and consumer verification. Profile names
do not bypass these requirements or create new release lines.
