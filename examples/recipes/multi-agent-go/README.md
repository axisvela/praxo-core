# Multi-Agent Delegation Recipe (Go)

This recipe exercises the asynchronous subagent manager: launch, observe, wait,
steer, cancel, list, and prune delegated tasks. It uses deterministic fake
runners and no model service or external agent.

**Evidence level: L1 contract recipe.** It demonstrates the delegation manager's
local task semantics. It does not prove durable child execution, remote agent
identity, cross-process recovery, or product multi-agent safety. See the
[multi-agent guide](../../../docs/guides/multi-agent.md) and the
[test and evidence taxonomy](../../../docs/project/test-taxonomy.md).

Run from this directory:

```sh
GOWORK=off go test -mod=readonly -v ./...
```

The tests show:

- launch requires a parent session and agent id;
- completion, failure, cancellation, and default isolated mode;
- a mid-flight update is forwarded only while the task is running;
- an update is rejected when the runner is not controllable or the task is
  terminal;
- List filters by parent session and Prune removes terminal tasks only;
- Wait honors context cancellation and rejects unknown task ids.

From the repository root, `python scripts/test_go_multi_agent_recipe.py -v`
repeats the checks in a fresh temporary module using the published package.
