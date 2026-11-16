# 31-Language Coverage Matrix

The example catalog covers thirteen integration themes across thirty-one language
implementations. Each theme has a deterministic check that does not require a
provider endpoint.

| Theme | Languages | Entry |
| --- | --- | --- |
| Consumer starter | 31 | `language/<language>/examples/consumer` |
| Live model | 31 | `language/<language>/examples/live-model` |
| Checkpoint allowlist | 31 | `language/<language>/examples/checkpoint` |
| Event sink | 31 | `language/<language>/examples/event-sink` |
| Retry | 31 | `language/<language>/examples/retry` |
| Provider fallback | 31 | `language/<language>/examples/provider-fallback` |
| Streaming | 31 | `language/<language>/examples/streaming` |
| Structured output | 31 | `language/<language>/examples/structured-output` |
| Identity and policy | 31 | `language/<language>/examples/identity-policy` |
| HTTP service | 31 | `language/<language>/examples/service` |
| MCP | 31 | `language/<language>/examples/mcp` |
| HITL | 31 | `language/<language>/examples/hitl` |
| Session checkpoint | 31 | `language/<language>/examples/session-checkpoint` |

Go keeps its reference recipes and examples under `examples/`.

GNU Octave reuses the shared MATLAB examples under `language/matlab/examples/`;
`matlab-octave-core` is a shared implementation and has no separate example root.

Run `python scripts/check_example_coverage.py --report` for the current
per-language matrix. Coverage requires a `README.md` and at least one source
file; a README-only directory does not count as an implementation.

This is a source-presence check, not an execution or semantic-parity test.
Distinguish example depth from verification:

| Depth | Required behavior |
| --- | --- |
| Mechanism check | Isolated schema, handler, or callback assertions; may not invoke Core |
| Core integration | Invokes the actual Core/model/tool/policy seam for the claimed behavior |
| Application tutorial | Documents setup, an input-to-output task, failure handling, and continuation |

A recorded run is a separate evidence dimension: name its revision, toolchain,
command, output, and limits. A mechanism check can have a recorded run without
becoming an application tutorial. The catalog has not been fully audited against
these depth labels; do not infer equal depth from the counts above.

## Coverage

All 31 declared languages provide both HITL and session-checkpoint examples.
Go uses its root examples, and Octave reuses the MATLAB examples. For
transport-seam or shared-runtime examples, the language README states the
required caller-owned transport or inherited runtime.

## Languages and Verification

The table below covers the sixteen primary Core languages. The fifteen
additional SDK languages are listed in the per-theme sections.

| Language | Example root | Local / CI evidence |
| --- | --- | --- |
| Go | `examples/` and `examples/recipes/` | Go tests and recipes |
| Python | `language/python/examples/` | Published PyPI package; CI |
| TypeScript | `language/typescript/examples/` | Published npm package; CI |
| Java | `language/java/examples/` | Published Maven package; CI |
| Rust | `language/rust/examples/` | Published crates.io package; CI |
| C# | `language/csharp/examples/` | Published NuGet package; CI |
| Ruby | `language/ruby/examples/` | Source SDK; local and CI |
| PHP | `language/php/examples/` | Source SDK; local and CI |
| C | `language/c/examples/` | Source library; local and CI |
| C++ | `language/cpp/examples/` | Source library; CI CMake targets |
| Fortran | `language/fortran/examples/` | Source modules; local and CI |
| Elixir | `language/elixir/examples/` | Source modules; local and CI |
| Erlang | `language/erlang/examples/` | Source modules; local and CI |
| Lua | `language/lua/examples/` | Source modules; local and CI |
| R | `language/r/examples/` | Source modules; local and CI |
| COBOL | `language/cobol/examples/` | Source modules; local and CI |

## Run a Theme

Use the README in each example directory for the exact command. Common forms:

```bash
# Published packages
cd language/python/examples/checkpoint && python -m unittest ...
cd language/typescript/examples/checkpoint && npm test
cd language/csharp/examples/checkpoint && dotnet run -- --test
cd language/java/examples/checkpoint && mvn -q compile exec:java
cd language/rust/examples/checkpoint && cargo run

# Source SDKs
ruby -I language/ruby/lib language/ruby/examples/checkpoint/checkpoint.rb
php language/php/examples/checkpoint/checkpoint.php
python language/fortran/examples/checkpoint/run.py
python language/cobol/examples/checkpoint/build.py
```

## Scope Notes

- Published-package examples prove installation and API use for the listed
  package version. Source examples prove repository integration.
- HTTP service examples for C/C++/Fortran/Elixir/Erlang/Lua/R/COBOL/Ruby/PHP are
  transport-neutral request handlers; Python/TypeScript/C#/Rust/Java include
  executable servers.
- Streaming examples use provider deltas where the SDK exposes them and agent
  stream parts where the SDK exposes lifecycle parts.
- These examples do not provide production identity, durable storage, sandboxing,
  or exactly-once delivery. Those remain application responsibilities.

See [Examples](examples.md) for the task-oriented catalog.

## Additional SDK Languages: Retry

The Retry theme is also available for Dart, Perl, Julia, Swift, Haskell, OCaml,
D, Nim, Zig, V, Delphi, PowerShell, MATLAB, and Objective-C under
`language/<language>/examples/retry`. These are deterministic source examples;
toolchain availability determines which run in CI.

## Additional SDK Languages: Checkpoint

Checkpoint allowlist examples are also available for Dart, Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, PowerShell, MATLAB, and Objective-C under `language/<language>/examples/checkpoint`.

## Additional SDK Languages: Event Sink

Event sink examples are also available for Dart, Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, PowerShell, MATLAB, and Objective-C under `language/<language>/examples/event-sink`.

## Additional SDK Languages: Provider Fallback

Provider fallback examples are also available for Dart, Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, PowerShell, MATLAB, and Objective-C under `language/<language>/examples/provider-fallback`.

## Additional SDK Languages: Structured Output

Structured output examples are also available for Dart, Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, PowerShell, MATLAB, and Objective-C under `language/<language>/examples/structured-output`. The [Structured Output tutorial](../guides/structured-output-tutorial.md) lists the run command for every declared language.

## Additional SDK Languages: Streaming

Streaming accumulation examples are also available for Dart, Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, PowerShell, MATLAB, and Objective-C under `language/<language>/examples/streaming`. These are transport-neutral chunk accumulation examples.

## Additional SDK Languages: Identity and Policy

Identity and policy examples are also available for Dart, Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, PowerShell, MATLAB, and Objective-C under `language/<language>/examples/identity-policy`.

## Additional SDK Languages: HTTP Service

Transport-neutral HTTP handler examples are also available for Dart, Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, PowerShell, MATLAB, and Objective-C under `language/<language>/examples/service`.

## Additional SDK Languages: MCP

MCP transport examples are available for Dart, Perl, Julia, Swift, Haskell,
OCaml, D, Nim, Zig, V, Delphi, PowerShell, MATLAB, and Objective-C under
`language/<language>/examples/mcp`. The MATLAB and PowerShell examples are
transport-neutral because those Cores do not bundle an MCP client.

## Advanced Examples

Application-level delegation examples are available for Go, Python,
TypeScript, Java, C#, and Rust. Go also has reference examples for long-running
operations, governed workspaces, and plugins. The remaining declared languages
do not yet have advanced examples; missing entries are recorded gaps, not
passes. See [Advanced examples](../guides/advanced-examples.md) and run
`python scripts/check_example_coverage.py --report-advanced` for the current
per-language report.
