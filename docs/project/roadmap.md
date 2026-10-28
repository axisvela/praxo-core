# Public Roadmap

Current core release: `2.5.0`. This page describes technical direction, not a
delivery schedule or a promise that every Core implementation supports every feature.

## Current Focus

- Strengthen containment against filesystem races, process-tree escapes, and WASM resource exhaustion.
- Improve runnable observability examples and event/OpenTelemetry guidance.
- Verify optional workspace adapters against live providers before promoting their contracts.
- Encourage independent implementations of the shared conformance suite.
- Improve language-specific installation, distribution, and compatibility evidence.

## Compatibility Commitments

Keep the public Go API small, preserve the MIT boundary, and require consumers
and tests for new contracts. Core implementations must not widen the Go API merely to simplify
a port. See [compatibility policy](compatibility-policy.md),
[Core support](../languages/support.md), and [language policy](../contributing/language-policy.md).

## Delivered Work

See [release history](../releases/index.md) and the
[changelog](https://github.com/axisvela/praxo-core/blob/main/CHANGELOG.md).
Optional adapter evaluation is not equivalent to live production verification.
