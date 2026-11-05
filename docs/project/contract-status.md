# Contract and Evidence Status

**Status:** public planning reference, 2026-11-05. This page defines the status
words used in the roadmap and records the current state of major contract areas.
It is not a release schedule and does not expand any API or profile.

## Status Words

| Status | Meaning | Minimum evidence |
| --- | --- | --- |
| Implemented | The normative contract or public API exists in the Go reference and has automated tests | Source, API snapshot where applicable, and tests |
| Verified | Evidence is bound to a specific commit, artifact, and date | A recorded run or review for that exact revision |
| Proposed | Design or acceptance criteria only | A design document; no API, wire, or profile guarantee |
| Experimental | Available for a named consumer, but may change and is not in the stable promise | A consumer and tests that state the limits |
| Not run / Not started | No result or implementation evidence exists yet | None; do not report as passing |

`Verified` is scoped evidence. A later documentation-only commit does not extend
it. Integration tests do not prove adoption, and conformance tests do not prove
production security or operational readiness.

These words describe contract and evidence state. They do not replace the
language coverage labels `planned`, `partial`, `parity`, and `n/a` in
[`spec/parity.md`](https://github.com/axisvela/praxo-core/blob/main/spec/parity.md)
or the support levels in the [language matrix](../languages/matrix.md).

## Current Matrix

| Area | Status | Scope and limits |
| --- | --- | --- |
| Go reference API and shared wire artifacts (events, errors, JSON Schema subset, plugin) | Implemented; verified per release revision | Normative files and vectors in `spec/`; does not prove live providers or product deployments |
| Tool, Model, and Checkpoint wire descriptions | Implemented; descriptive at `SPEC_VERSION` 0.2.0 | Shared tool/model shapes and the checkpoint allowlist envelope are wire; Go checkpoint and parsed-tool-call projections are documented as `"wire": false` and are not frozen cross-language contracts |
| Go, Python, TypeScript, and Java consumer starters | Implemented; verified at their cited revisions | Published-package installation, build, and deterministic allow/deny checks; integration evidence, not adoption evidence |
| Go, Python, TypeScript, and Java governed negative acceptance | Implemented; verified at their cited revisions | Five application-level checks in each: missing policy/scope, final-argument and approval-edit reauthorization, policy-service failure; not a general profile |
| Go identity/policy recipe | Implemented; verified at its cited revision | Verified principal supplied by the application; missing, expired, tenant-mismatch, and model-role cases deny; not an identity provider or PDP |
| Governed Execution Profile | Proposed | The design defines acceptance criteria; no general Core profile is implemented |
| Coding-agent integration map | Implemented; versions checked by documentation tests | Package map, integration contract, and verification commands; not an install channel, automatic skill, or adoption evidence |
| Coding-agent skill template | Experimental; repository template only | Tool-neutral `SKILL.md`; installation and discovery are not verified, and no auto-install, MCP, or runtime-skill behavior is claimed |
| Registry page metadata | Source metadata updated; published pages not yet updated | PyPI, npm, Maven, and Go pages audited 2026-11-05; pages update only with a new release; other registries are release-checked |
| Coding-agent adoption experiments | Not run | No discovery, selection, first-pass, repair-cost, or retention data |
| Embodied Integration Profile | Not started | Requires a named consumer, middleware choice, and simulation scenario |
| Language conformance, feature coverage, and operational evidence | See `spec/parity.md`, the language matrix, and Behavior Lab | Separate dimensions; a released source tag does not supply operational evidence |

## Citing Evidence

When citing a status, name the revision, artifact, and result. Say which of these
the evidence covers:

1. contract conformance;
2. a published-package consumer check;
3. a real local service or provider integration;
4. a hardware, simulation, or production observation.

Do not use one level to imply another. An explicitly required framework in a
coding-agent experiment is directed-integration evidence, not free-selection
evidence. Correctly excluding an unsuitable framework is a successful selection
decision, not an adoption failure.

For shared-wire change classification, see the normative rules in
[`spec/README.md`](https://github.com/axisvela/praxo-core/blob/main/spec/README.md)
and the [compatibility policy](compatibility-policy.md). Optional profiles do not
bypass wire, parity, or conformance review.
