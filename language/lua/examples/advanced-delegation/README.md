# Lua Governed Delegation

This is an application-level parent/child delegation example. It uses the
existing `praxo.agent` tool scope, policy, middleware, and cancellation seams.
It does not add or change Core API.

Run the checks from the repository root:

```bash
lua language/lua/examples/advanced-delegation/governance.lua
```

Expected output:

```text
scope escalation: rejected; effects=0
depth limit: grandchild rejected; effects=0
child limit: enforced and released
sibling budget: effects=1
cancellation: zero effects
final argument reauthorization: denied; effects=0
lua governance: delegation checks passed (6)
```

The six checks cover:

- child tool scope cannot exceed the parent delegable scope;
- a grandchild is rejected at `max_depth`;
- `max_children` is enforced and released;
- two siblings share one budget and only the first produces an effect;
- parent cancellation propagates to the child and prevents the tool effect;
- a middleware argument edit is reauthorized against policy and denied before
  the tool runs.

Mechanisms: a deterministic in-process fixture; `record` is the only counted
effect and `parent_only` is outside the delegable scope; parent and child
policies are composed with a budget policy; siblings share one budget counter;
the application governor enforces `max_depth` and `max_children`; the agent
`cancellation` callback is checked before tool invocation. No network is used.
The checks run sequentially. All six checks are supported; none are unsupported.
Public Core API, wire, parity, and snapshots are unchanged. Parallel or batch
execution and durable task queues, retries, remote execution, and effect
reconciliation remain application responsibilities.
