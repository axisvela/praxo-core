# Advanced Delegation Governance (Ruby)

Application-level governed delegation checks for the Ruby Core.

```bash
ruby language/ruby/examples/advanced-delegation/governance_test.rb
```

Expected output:

```text
Ruby governance delegation checks passed (6)
```

The checks cover child tool-scope narrowing, depth and child-count limits, a
shared cumulative sibling budget, cancellation before effects, and
final-argument reauthorization after a middleware edit. Cancellation uses the
`AgentOptions#cancellation` callback.

The fixture model and in-memory tools are deterministic; no provider or network
is used. These checks are application-owned. The published Core API is
unchanged.
