# Advanced Examples

Advanced examples move beyond a single model/tool loop into delegation,
long-running operations, workspaces, plugins, and other application-owned
seams. They are not a new profile and do not imply production readiness.

## Application-Level Delegation

The parent/child delegation examples show an application-level pattern: a parent
agent calls a `delegate` tool, the tool runs a child agent with a different tool
scope and policy, and the child effect is verified before the parent completes.
The examples use only the shared agent, tool, and policy seams.

| Language | Example | Run |
| --- | --- | --- |
| Go | [`language/go/examples/multiagent`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/multiagent) | `go test ./...` |
| Python | [`language/python/examples/advanced-delegation`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/advanced-delegation) | `python delegation.py` |
| TypeScript | [`language/typescript/examples/advanced-delegation`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/advanced-delegation) | `npm start` |
| Java | [`language/java/examples/advanced-delegation`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/advanced-delegation) | `mvn -q compile exec:java` |
| C# | [`language/csharp/examples/advanced-delegation`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/advanced-delegation) | `dotnet run --project AdvancedDelegation.csproj` |
| Rust | [`language/rust/examples/advanced-delegation`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/advanced-delegation) | `cargo run` |

Across the Core SDK set, the governance examples also check child scope
narrowing, parent/child policy composition, shared sibling budgets, child-count
and depth limits, cancellation before effects, and final-argument
reauthorization. They do not implement automatic parent-policy inheritance or
cancellation propagation; those remain application responsibilities. The Go
manager example has its own lifecycle scope. Source availability is not execution
evidence for every package/toolchain; consult the recorded runs in the
[verification evidence](../project/verification-evidence.md) before claiming one.

This is not the Go `pkg/agent/delegation` contract. Durable workers, remote task
queues, retries, cancellation propagation, and effect reconciliation remain
application responsibilities.

## Long-Running Operations

The Go reference recipe
[`language/go/examples/recipes/long-running-go`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/long-running-go)
shows application-owned submit, status, cancel, recovery, fencing, verifier, and
durable-state patterns. See the
[long-running operation recipe](long-running-operations.md) for the full scope
and limits.

Long-running examples for other SDKs are not yet provided. Start from the Go
recipe and keep the operation state, effect verification, and reconciliation in
the application.

## Workspaces

The Go reference example
[`language/go/examples/governed-workspace`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/governed-workspace)
shows a governed, read-only workspace path. The
[workspace agent tutorial](workspace-agent-tutorial.md) is the guided
published-package version.

Workspace providers and VFS backends remain application-owned in SDKs that do
not expose a workspace seam. Do not infer workspace support from a language
having an agent loop.

## Plugins

The Go reference example
[`language/go/examples/plugin`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/plugin)
shows plugin lifecycle, guarded transitions, in-flight drain, revoke, and
quarantine. Plugin hosts remain Go-first; other Cores should state their gap
explicitly.

## Adding an Advanced Example

An advanced example is ready to publish when it:

1. runs deterministically without a provider endpoint;
2. checks a denial or isolation property, not only the happy path;
3. states whether it uses a Core seam or an application-level pattern;
4. records the package or source version and the exact command;
5. keeps credentials, durable state, isolation, and effect verification in the
   application.

Do not add a new language implementation or adapter only to complete a matrix.
Advanced work requires a named consumer and a concrete project need.

## Current Gaps

- Delegation examples cover Go, Python, TypeScript, Java, C#, and Rust. The
  remaining declared languages do not yet have a delegation example.
- Long-running, workspace, and plugin examples are Go-first. They are not
  promised across languages.
- Run `python scripts/check_example_coverage.py --report-advanced` for the
  current per-language advanced coverage. Missing entries are recorded gaps, not
  passes.

## Related

- [Examples](../getting-started/examples.md)
- [Language Coverage](../getting-started/language-coverage.md)
- [Multi-agent patterns](multi-agent.md)
- [Long-running operations](long-running-operations.md)
- [Plugins](plugins.md)
- [Execution profiles](../reference/execution-profiles.md)
