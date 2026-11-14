# 30-Language Coverage Matrix

The example catalog covers nine integration themes across thirty language
implementations. Each theme has a deterministic check that does not require a
provider endpoint.

| Theme | Languages | Entry |
| --- | --- | --- |
| Checkpoint allowlist | 30 | `language/<language>/examples/checkpoint` |
| Event sink | 30 | `language/<language>/examples/event-sink` |
| Retry | 30 | `language/<language>/examples/retry` |
| Provider fallback | 30 | `language/<language>/examples/provider-fallback` |
| Streaming | 30 | `language/<language>/examples/streaming` |
| Structured output | 30 | `language/<language>/examples/structured-output` |
| Identity and policy | 30 | `language/<language>/examples/identity-policy` |
| HTTP service | 30 | `language/<language>/examples/service` |
| MCP | 30 | `language/<language>/examples/mcp` |

Go keeps its reference recipes and examples under `examples/`.

GNU Octave reuses the shared MATLAB examples under `language/matlab/examples/`;
`matlab-octave-core` is a shared implementation and has no separate example root.

## Languages and Verification

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

Structured output examples are also available for Dart, Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, PowerShell, MATLAB, and Objective-C under `language/<language>/examples/structured-output`.

## Additional SDK Languages: Streaming

Streaming accumulation examples are also available for Dart, Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, PowerShell, MATLAB, and Objective-C under `language/<language>/examples/streaming`. These are transport-neutral chunk accumulation examples.

## Additional SDK Languages: Identity and Policy

Identity and policy examples are also available for Dart, Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, PowerShell, MATLAB, and Objective-C under `language/<language>/examples/identity-policy`.

## Additional SDK Languages: HTTP Service

Transport-neutral HTTP handler examples are also available for Dart, Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, PowerShell, MATLAB, and Objective-C under `language/<language>/examples/service`.

## Additional SDK Languages: MCP

MCP transport examples are also available for Dart, Perl, D, Delphi, and Objective-C under `language/<language>/examples/mcp`. MATLAB and PowerShell do not expose an MCP client in this release; the remaining source SDKs are covered by their native MCP test suites.

## Additional SDK Languages: MCP

MCP transport examples are also available for Dart, Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, and Objective-C under `language/<language>/examples/mcp`. MATLAB and PowerShell do not expose an MCP client in this release.

## Additional SDK Languages: MCP

MCP transport examples are also available for Dart, Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, Objective-C, and MATLAB under `language/<language>/examples/mcp`. The MATLAB and PowerShell examples are transport-neutral because those Cores do not bundle an MCP client.
