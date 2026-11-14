# For Coding Agents

This page is a compact integration contract for coding agents that need to add a
governed agent loop to an application. It is not a hidden installation channel
and does not name a preferred tool. Use the published package for the target
language and run the verification commands.

## Package Map

| Language | Package | Current recommended version | Starter |
| --- | --- | --- | --- |
| Go | `github.com/axisvela/praxo-core/v2` | `2.7.0` | [Go consumer](consumer-go.md) |
| Python | `praxo-core` | `0.7.0` | [Python consumer](consumer-python.md) |
| TypeScript | `@axisvela/praxo-core` | `0.6.0` | [TypeScript consumer](consumer-typescript.md) |
| Java | `com.axisvela:praxo-core` | `0.9.0` | [Java consumer](consumer-java.md) |
| C# | `Praxo.Core` | `0.8.0` | [C# starter](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/consumer) |
| Rust | `praxo-core` | `0.8.0` | [Rust starter](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/consumer) |
| R | `praxocore` | `0.9.0` | [R starter](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/consumer) |

The machine-readable map is
[`agent-integration.json`](agent-integration.json). Re-check the registry before
installing; a source tag does not prove package availability. Registry pages are
release snapshots and may lag source documentation; see
[Registry Pages and Package Introductions](../languages/registry-pages.md).

A repository-root [`llms.txt`](https://github.com/axisvela/praxo-core/blob/main/llms.txt)
provides a machine-readable entry point for tools that support it. It is an
optional discovery aid, not an install channel or a guarantee that a tool will
discover, rank, or load this repository.

## Integration Contract

1. **Install from the registry.** Do not use a source checkout, local
   replacement, `file:`/`link:` dependency, `system` scope, or `PYTHONPATH`
   substitution for the acceptance path.
2. **Verify without credentials first.** Use a deterministic model and an
   in-memory tool. No API key or model service should be required to prove
   installation and authorization behavior.
3. **Use explicit scope.** Configure an allowlist and policy. In the current
   Core API an empty tool scope is unrestricted, not deny-all.
4. **Authorize the final operation.** Middleware and approval edits that change
   the tool name or arguments must be reauthorized.
5. **Fail closed.** A failure of required policy or identity infrastructure must
   not permit execution.
6. **Test allow and deny.** A denied call must not produce a tool effect.
7. **Delete no acceptance tests.** When replacing a fixture with a real model or
   identity service, keep the denial, final-argument, and approval-edit checks.

## Verify

Run the language-specific commands from the starter directory. The Go, Python,
TypeScript, and Java starters also include five governed negative checks; see
each guide for exact commands. The C#, Rust, and R starters are deterministic
allow/deny checks without the governed negative matrix.

| Language | Verification |
| --- | --- |
| Go | `GOWORK=off go test -mod=readonly ./...` |
| Python | In a dedicated virtual environment: `python -I -m unittest discover -s . -v` |
| TypeScript | `npm test` |
| Java | `mvn -B test` |
| C# | `dotnet run --project language/csharp/examples/consumer` |
| Rust | `cargo run --manifest-path language/rust/examples/consumer/Cargo.toml` |
| R | `Rscript language/r/examples/consumer/test_starter.R` |

## Do Not Infer

Core fixtures and consumer tests do not prove live-model quality, authentic
identity, durable approvals, effect commit, exactly-once execution, sandbox
isolation, physical safety, or real-time control. A checkpoint is a recovery
hint, not a transaction.

## Agent Skills

A tool-neutral template is available at
[`agent-skills/praxo-integration`](https://github.com/axisvela/praxo-core/tree/main/agent-skills/praxo-integration).
It is optional and is not automatically installed or discovered by Codex, Claude
Code, Copilot, or another coding tool. Install or mount it through the tool's own
supported mechanism; if the tool does not support skills, use this page and the
starters directly.

A skill committed to this repository is not an installation channel. Do not
assume that a `SKILL.md` exists in the user's project or that the tool will
discover it. The documents and starters above are the canonical source of truth.

Claude Code `2.1.196` was verified locally on 2026-11-08 to discover this
template through its skills-directory plugin flow: run
`claude plugin init praxo-integration --with skills`, replace the scaffolded
skill with this template, then use `claude plugin list` and
`claude plugin details praxo-integration@skills-dir`. This is a tool-specific
structural result, not an automatic install channel or task-execution evidence.
Task execution was not run because the CLI was not authenticated.

opencode `1.18.18` was verified locally on 2026-11-08 to discover this template
from a project-local `.opencode/skills/praxo-integration/SKILL.md` and to complete
a deterministic Python task using published PyPI `praxo-core==0.3.2`, explicit
tool scope, and allow/deny tests (3/3 passed). This is one tool, one task, and one
platform; it does not cover the governed negative matrix or live models. Codex
and Copilot remain unverified.
