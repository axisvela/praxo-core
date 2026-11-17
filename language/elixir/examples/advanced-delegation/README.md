# Advanced Delegation Governance (Elixir)

Application-level governed delegation checks for the Elixir Core.

```bash
mkdir -p language/elixir/build/ebin
elixirc -o language/elixir/build/ebin language/elixir/lib/praxo/*.ex language/elixir/lib/praxo/adapters/*.ex
elixir -pa language/elixir/build/ebin language/elixir/examples/advanced-delegation/governance_test.exs
```

If `language/elixir/build/ebin` already contains the compiled beams, only the
last command is needed. Expected output:

```text
Elixir governance delegation checks passed (6)
```

The checks cover child tool-scope narrowing, depth and child-count limits, a
shared cumulative sibling budget, cancellation before effects, and
final-argument reauthorization after a middleware edit. Cancellation uses the
`AgentOptions.cancellation` callback.

The fixture model and in-memory tools are deterministic; no provider or network
is used. These checks are application-owned. The published Core API is
unchanged.
