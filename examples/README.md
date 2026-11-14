# Examples

This directory holds Go reference examples and cross-language integration
examples. Language-specific examples live under
`language/<language>/examples/` so they are included in the dedicated language
mirror repositories.

## First Agent

- [Live Model Golden Path](../language/go/examples/live-model/README.md): published packages connected
  to an OpenAI-compatible endpoint.
- [Quickstart](quickstart/): Go reference endpoint example.

## Build a Prototype

- [Workspace agent](workspace-agent/): read-only published-package Go application.
- [Embedded service](embedded-service/): vendor-neutral HTTP service with caller context, policy, timeouts, and graceful shutdown.
- [Authenticated service](embedded-service-auth/): HMAC bearer token and tenant-scoped policy variant.
- [Reference agent](reference/): workspace-oriented reference application.
- [Governed workspace](governed-workspace/): policy and approval boundaries.
- [Checkpoint](checkpoint/): checkpoint store usage.
- [Plugin](plugin/): plugin host and example plugin.
- [Multi-agent](multiagent/): local delegation patterns.
- [Recipes](recipes/): focused integration recipes.
- [Ecosystem](ecosystem/): optional ecosystem adapters.

## Examples vs Recipes

- [`recipes/`](recipes/): Go-focused copy-paste recipes and L1-L4 test evidence.
  Use these for mechanics, failure boundaries, and focused tests.
- `examples/`: runnable projects, including published-package and
  language-specific integrations. Use these to start an application.

There is intentional overlap. For example:

| Topic | Recipe | Runnable example |
| --- | --- | --- |
| Structured output | [`recipes/structured-output-go`](recipes/structured-output-go) | Python / TypeScript / Java / C# / Rust / Ruby / PHP / C / C++ / Fortran / Elixir / Erlang / Lua / R / COBOL `structured-output` |
| Provider fallback | [`recipes/provider-fallback-go`](recipes/provider-fallback-go) | Python / TypeScript / C# / Rust / Java / Ruby / PHP / C / C++ / Fortran / Elixir / Erlang / Lua / R / COBOL `provider-fallback` |
| Event sinks | [`recipes/event-sinks-go`](recipes/event-sinks-go) | Python / TypeScript / C# / Rust / Java / Ruby / PHP / C / C++ / Fortran / Elixir / Erlang / Lua / R / COBOL `event-sink` |
| Streaming | [`recipes/streaming-go`](recipes/streaming-go) | Python / TypeScript / C# / Rust / Java / Ruby / PHP / C / C++ / Fortran / Elixir / Erlang / Lua / R / COBOL `streaming` |
| MCP tools | [`ecosystem/mcp`](ecosystem/mcp) | Python / TypeScript / C# / Rust / Java / Ruby / PHP / Elixir / Erlang / Lua / R / C / C++ / Fortran / COBOL `mcp` |
| Retry | [`recipes/retry-go`](recipes/retry-go) | Python / TypeScript / C# / Rust / Java / Ruby / PHP / C / C++ / Fortran / Elixir / Erlang / Lua / R / COBOL `retry` |
| Checkpoint store | [`recipes/checkpoint-store-go`](recipes/checkpoint-store-go) | [`checkpoint`](checkpoint), [`embedded-service-auth`](embedded-service-auth), and Python / TypeScript / C# / Rust / Java / Ruby / PHP / C / C++ / Fortran / Elixir / Erlang / Lua / R / COBOL `checkpoint` |
| Identity and policy | [`recipes/identity-go`](recipes/identity-go) | [`embedded-service-auth`](embedded-service-auth), and Python / TypeScript / C# / Rust / Java / Ruby / PHP / C / C++ / Fortran / Elixir / Erlang / Lua / R / COBOL `identity-policy` |
| HTTP service | [`embedded-service`](embedded-service) | Python / TypeScript / C# / Rust / Java / Ruby / PHP / C / C++ / Fortran / Elixir / Erlang / Lua / R / COBOL `service` |
| VFS containment | [`recipes/vfs-containment-go`](recipes/vfs-containment-go) | [`workspace-agent`](workspace-agent) |
| Long-running operations | [`recipes/long-running-go`](recipes/long-running-go) | [`embedded-service-auth`](embedded-service-auth) |

Start with the recipe for the mechanism, then use the example for an
application-shaped integration. Do not copy both into one project.

## By Language

| Language | Examples |
| --- | --- |
| Go | [live-model](../language/go/examples/live-model/go), [consumer](../language/go/examples/consumer-go), and this directory |
| Python | [language/python/examples](../language/python/examples) |
| TypeScript | [language/typescript/examples](../language/typescript/examples) |
| Java | [language/java/examples](../language/java/examples) |
| C# | [language/csharp/examples](../language/csharp/examples) |
| Rust | [language/rust/examples](../language/rust/examples) |
| Ruby | [language/ruby/examples](../language/ruby/examples) |
| PHP | [language/php/examples](../language/php/examples) |
| C | [`language/c/examples`](../language/c/examples) |
| C++ | [`language/cpp/examples`](../language/cpp/examples) |
| Fortran | [`language/fortran/examples`](../language/fortran/examples) |
| Erlang | [`language/erlang/examples`](../language/erlang/examples) |
| R | [`language/r/examples`](../language/r/examples) |
| COBOL | [`language/cobol/examples`](../language/cobol/examples) |
| Elixir | [language/elixir/examples](../language/elixir/examples) |
| Lua | [language/lua/examples](../language/lua/examples) |

Each language example directory has its own README with install and run
commands. Published-package examples do not require a repository checkout.
