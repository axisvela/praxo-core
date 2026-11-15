# Live Model Golden Path

This is the shortest path from a published PRAXO-CORE package to a real model
response. It uses an OpenAI-compatible endpoint, one low-risk `get_time(zone)`
tool with a small parameter schema, and an explicit policy that permits only
`get_time`.

The Go project lives in
[`language/go/examples/live-model/go`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/live-model/go).
Language-specific projects live under `language/<lang>/examples/live-model`, for
example [`language/python/examples/live-model`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/live-model).
Those directories are included in the dedicated language mirrors.

## Prerequisites

- A supported language toolchain.
- Ollama running locally, or another OpenAI-compatible endpoint.
- No PRAXO-CORE source checkout is required.

Install a model for Ollama. `qwen3.5:4b` is a good small local option; any
OpenAI-compatible model name served by your endpoint also works:

```bash
ollama pull qwen3.5:4b
```

Configure the endpoint:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=qwen3.5:4b
# export PRAXO_API_KEY=...   # only for hosted endpoints
```

On PowerShell:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
```

If `qwen3.5:4b` is not available in your Ollama installation, use another
installed model such as `llama3.2` and set `PRAXO_MODEL` accordingly.

## Run by Language

| Language | Package | Commands |
| --- | --- | --- |
| Go | `github.com/axisvela/praxo-core/v2@v2.8.0` | `cd language/go/examples/live-model/go; go run .` |
| Python | PyPI `praxo-core==0.8.0` | `cd language/python/examples/live-model; python -m venv .venv; .venv/bin/python -m pip install -r requirements.txt; .venv/bin/python live_starter.py` |
| TypeScript | npm `@axisvela/praxo-core@0.7.0` | `cd language/typescript/examples/live-model; npm install; npm start` |
| Java | Maven `com.axisvela:praxo-core:0.9.0` | `cd language/java/examples/live-model; mvn -q compile exec:java` |
| C# | NuGet `Praxo.Core==0.9.0` | `cd language/csharp/examples/live-model; dotnet run` |
| Rust | crates.io `praxo-core==0.9.0` with `http-ureq` | `cd language/rust/examples/live-model; cargo run` |
| R | r-universe `praxocore==0.10.0` | `cd language/r/examples/live-model; Rscript live.R` |
| Ruby | source | `ruby -I language/ruby/lib language/ruby/examples/live-model/live_starter.rb` |
| PHP | source | `php language/php/examples/live-model/live_starter.php` |
| Elixir | source | `elixir -pa language/elixir/build/ebin language/elixir/examples/live-model/live_starter.exs` |
| Lua | source | `lua language/lua/examples/live-model/live_starter.lua` |
| OCaml | source, transport seam | `ocaml unix.cma language/ocaml/examples/live-model/live_model.ml` (supply a transport; see README) |
| PowerShell | PowerShell `0.6.0` wrapper over C# Core `0.9.0` | `dotnet build language/csharp/Praxo.Core/Praxo.Core.csproj -c Release; pwsh -NoProfile -File language/powershell/examples/live-model/live_model.ps1` |
| V | source | `v -path "language/v|@vlib|@vmodules" language/v/examples/live-model/live_model.v` |
| Zig | source | build from README: `language/zig/examples/live-model/README.md` |

The Go, Python, TypeScript, Java, C#, Rust, and R examples import a published
package. The Ruby, PHP, Elixir, Lua, OCaml, V, and Zig examples run against
repository source so they use the current adapter code; their READMEs also
document package install where available. The Rust example enables the
`http-ureq` feature from the published `0.9.0` crate. PowerShell loads the C#
Core assembly and inherits its OpenAI-compatible adapter. The OCaml Core does
not bundle an HTTP client, so its example is a transport seam rather than a
fully runnable live client.

Python `0.7.0`, TypeScript `0.6.0`, and Java `0.9.0` include the OpenAI
tool-wire fix for tool-result follow-ups.

## What It Demonstrates

- a model adapter configured from environment variables;
- tool registration through the language Core;
- an allowlist restricted to `get_time`;
- a policy hook that denies every other tool;
- one normal agent run with the model response printed to the console.

## Denial Check

The live path does not assume the model will request a dangerous tool. Run the
matching consumer starter to verify deterministic allow/deny behavior and that a
denied call produces no tool effect:

- [Go consumer](consumer-go.md)
- [Python consumer](consumer-python.md)
- [TypeScript consumer](consumer-typescript.md)
- [Java consumer](consumer-java.md)
- [C# starter](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/consumer)
- [Rust starter](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/consumer)
- [R starter](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/consumer)
- [Ruby starter](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/consumer)
- [PHP starter](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/consumer)
- [Elixir starter](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/consumer)
- [Lua starter](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/consumer)
- [OCaml starter](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/examples/consumer)
- [PowerShell starter](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/consumer)
- [V starter](https://github.com/axisvela/praxo-core/tree/main/language/v/examples/consumer)
- [Zig starter](https://github.com/axisvela/praxo-core/tree/main/language/zig/examples/consumer)

## Troubleshooting

- **Connection refused:** confirm `PRAXO_BASE_URL` includes `/v1` when required
  by the endpoint.
- **Model not found:** check `PRAXO_MODEL` against the model name served by the
  endpoint.
- **Authentication error:** set `PRAXO_API_KEY` for hosted endpoints.
- **No tool call:** ask the model explicitly to use `get_time`; some small models
  answer from context instead of calling tools.
- **Timeout:** use a smaller model or increase the adapter timeout in the
  language example.

The example is an integration starting point, not a production security profile.
Identity, durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
