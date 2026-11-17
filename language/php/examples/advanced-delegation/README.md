# Advanced Delegation Governance (PHP)

Application-level governed delegation checks for the PHP Core.

```bash
php language/php/examples/advanced-delegation/governance_test.php
```

Expected output:

```text
PHP governance delegation checks passed (6)
```

The checks cover child tool-scope narrowing, depth and child-count limits, a
shared cumulative sibling budget, cancellation before effects, and
final-argument reauthorization after a middleware edit. Cancellation uses the
`AgentOptions::$cancellation` callback.

The fixture model and in-memory tools are deterministic; no provider or network
is used. These checks are application-owned. The published Core API is
unchanged.
