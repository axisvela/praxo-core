# Test and Evidence Taxonomy

**Status:** public evidence guide, 2026-11-05. A passing test does not say what it
proves unless you know its level. Use this page before citing a test as Core
capability, integration evidence, or adoption evidence.

## Levels

| Level | Evidence | What it can prove | What it cannot prove |
| --- | --- | --- | --- |
| L1 Core contract and behavior | `pkg/...` tests, `spec/vectors/`, API snapshots | The Go reference implements the stated local behavior or contract | Published packages, other SDKs, or production behavior |
| L2 SDK conformance | `language/...` tests, parity and conformance runners | A declared SDK scope matches the vectors it claims | Full Go parity, live providers, or adoption |
| L3 Published-package consumer | `examples/consumer-go`, `consumer-python`, `consumer-typescript`, `consumer-java` | A registry artifact installs, builds, and exercises public API paths such as allow/deny | Core internals, production security, or that anyone adopted it |
| L4 Application recipe | Identity binding, governed acceptance glue, long-running operation fixtures and verifier/fencing demos | The reference application pattern behaves as described, including stated failure boundaries | That Core owns the external service, store, verifier, or policy decision |
| L5 Adoption experiment | Agent Adoption Lab records | How coding tools discover, select, integrate, and retain the framework under fixed conditions | Correctness of the framework itself |
| L6 Production and operational | Deployment, platform, hardware, and independent review records | The tested deployment or environment | Other environments or future revisions |

`Verified` is always scoped to a revision, artifact, and date. A later commit does
not extend it.

## `examples/consumer-go` Map

| File | Level | Core seam actually exercised | Recipe or application behavior |
| --- | --- | --- | --- |
| `main_test.go` | L3, with L1 behavior through public API | Tool loop, policy allow/deny, published-package import | Deterministic fixture and output |
| `governed_test.go` | L3/L4 | Final tool arguments reauthorized, approval edit reauthorized, policy error propagation | Missing-policy and empty-scope guards are application checks; Core keeps nil-policy embedding |

The identity recipe has moved to
[`examples/recipes/identity-go`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/identity-go).
It supplies a verified principal through a trusted context; the principal,
role, tenant, and expiry decisions are application logic, not a Core identity
service.

The long-running suite has moved to
[`examples/recipes/long-running-go`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/long-running-go)
so the starter does not mix L3 package checks with L4 recipes. The recipe is
valuable as a reference integration and as a statement of what the application
must own. It is not evidence that Core provides durable operations, HTTP
authentication, effect verification, leases, or fencing. Only its Run-cancellation
assertion touches a Core seam.

Core-level equivalents are tested separately: see `pkg/agent` tests for policy
denial, final-argument authorization, allowed tools, and cancellation, and
`spec/vectors` for shared behavior.

## Should Recipe Behavior Move Into Core?

Do not internalize a recipe simply because its tests pass. Core should absorb a
semantic only when all of these hold:

1. A named consumer needs it across more than one application.
2. The semantic is stable and belongs to local agent execution, not to an
   external service, store, identity system, or transport.
3. It fits the public API without widening it for a single product.
4. Negative tests and compatibility impact are understood.
5. If it is shared behavior, it has a `spec/` contract, vectors, parity, and SDK
   impact review.

Durable operation storage, HTTP authentication, independent effect verification,
fencing stores, and lease expiry do **not** meet that test today. They remain
application, integration, or product responsibilities. A future shared async
operation lifecycle could be proposed as a Spec profile with conformance vectors;
that is not the same as adding a Core API by default.

## Citing Tests

Say the level, revision, command, and result. For example:

- "L1: `pkg/agent` test at SHA ..."
- "L3: published Go 2.5.2 consumer test at SHA ..."
- "L4: long-running recipe at SHA ...; not a Core capability claim"
- "L5: not run; no adoption data"

Do not cite a recipe fixture as proof of a Core feature, and do not cite a
consumer install as evidence of adoption.
