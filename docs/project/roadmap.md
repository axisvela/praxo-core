# Public Roadmap

Current core release: `2.5.1`. This page describes technical direction, not a
delivery schedule or a promise that every Core implementation supports every feature.

## Current Focus

Prioritize verifiable behavior over additional language, provider, or tool counts.
The following are acceptance targets, not statements that the work is complete.

| Direction | Acceptance target |
| --- | --- |
| Release and verification integrity | Documentation and release gates agree with canonical version metadata; skipped tests and stale reports cannot be presented as current passes |
| Governed integration | Missing mandatory controls, denied authorization, and security dependency failures prevent execution; final tool arguments remain subject to authorization |
| Context trust | Memory, skills, tool results, and compacted summaries retain their source and trust distinctions rather than implicitly becoming trusted instructions |
| Effect recovery | Version-pinned integration tests distinguish execution intent, business commit, evidence persistence, and uncertain outcomes; retries do not blindly repeat effects |
| Containment | Filesystem race, process-tree escape, and WASM resource-exhaustion tests state platform limits and residual risks |
| Provider and observability evidence | Runnable event/OpenTelemetry examples and live workspace-provider verification support only their tested claims; workspace contract promotion requires two-provider review |
| Language support | Contract conformance, feature coverage, and operational evidence are reported separately; published implementations continue receiving applicable security corrections |

See the [governed execution design](../reference/governed-execution.md) for proposed
boundaries and the [test evidence standard](../contributing/test-evidence.md) for
recording environment, configuration, procedure, data, results, and findings.

## Verification Boundaries

Core tests establish framework behavior. Cross-repository tests establish only
the integrations and versions they actually execute. Historical local service
runs are valuable evidence, but do not certify the current release, independent
reproduction, or production readiness.

New shared security or effect contracts require a named consumer and negative
tests before API promotion. Identity issuance, policy decision services, effect
ledgers, and durable workflow engines remain integration responsibilities.
The design does not change the default behavior or public API of `2.5.1`.

## Compatibility Commitments

Keep the public Go API small, preserve the MIT boundary, and require consumers
and tests for new contracts. Core implementations must not widen the Go API merely to simplify
a port. See [compatibility policy](compatibility-policy.md),
[Core support](../languages/support.md), and [language policy](../contributing/language-policy.md).

## Delivered Work

See [release history](../releases/index.md) and the
[changelog](https://github.com/axisvela/praxo-core/blob/main/CHANGELOG.md).
Optional adapter evaluation is not equivalent to live production verification.
