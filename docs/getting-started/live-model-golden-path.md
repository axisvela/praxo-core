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
| Go | `github.com/axisvela/praxo-core/v2@v2.9.0` | `cd language/go/examples/live-model/go; go run .` |
| Python | PyPI `praxo-core==0.9.0` | `cd language/python/examples/live-model; python -m venv .venv; .venv/bin/python -m pip install -r requirements.txt; .venv/bin/python live_starter.py` |
| TypeScript | npm `@axisvela/praxo-core@0.8.0` | `cd language/typescript/examples/live-model; npm install; npm start` |
| Java | Maven `com.axisvela:praxo-core:0.9.0` | `cd language/java/examples/live-model; mvn -q compile exec:java` |
| C# | NuGet `Praxo.Core==0.9.1` | `cd language/csharp/examples/live-model; dotnet run` |
| Rust | crates.io `praxo-core==0.9.1` with `http-ureq` | `cd language/rust/examples/live-model; cargo run` |
| R | r-universe `praxocore==0.10.1` | `cd language/r/examples/live-model; Rscript live.R` |
| Ruby | source | `ruby -I language/ruby/lib language/ruby/examples/live-model/live_starter.rb` |
| PHP | source | `php language/php/examples/live-model/live_starter.php` |
| Elixir | source | `elixir -pa language/elixir/build/ebin language/elixir/examples/live-model/live_starter.exs` |
| Lua | source | `lua language/lua/examples/live-model/live_starter.lua` |
| OCaml | source, transport seam | `ocaml unix.cma language/ocaml/examples/live-model/live_model.ml` (supply a transport; see README) |
| PowerShell | PowerShell `0.7.0` wrapper over C# Core `0.9.1` | `dotnet build language/csharp/Praxo.Core/Praxo.Core.csproj -c Release; pwsh -NoProfile -File language/powershell/examples/live-model/live_model.ps1` |
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

The Go example also includes a guarded live test:

```bash
PRAXO_LIVE_TEST=1 PRAXO_BASE_URL=http://127.0.0.1:11434/v1 \
  PRAXO_MODEL=qwen3.5:4b go test -run TestRunAgainstLiveEndpoint -v .
```

It skips unless `PRAXO_LIVE_TEST=1`, so normal CI stays deterministic.

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

| Symptom | Check | Fix |
| --- | --- | --- |
| Connection refused or DNS failure | `PRAXO_BASE_URL` | Use the full API root, usually ending in `/v1`. For Ollama: `http://localhost:11434/v1`. Do not point at a web UI or model download URL. |
| 404 or "no such endpoint" | Base URL path | Hosted providers often require `/v1`; remove a duplicated `/v1/v1`. Check the provider's compatibility base URL. |
| 401 or 403 from a hosted endpoint | `PRAXO_API_KEY` | Set a valid key; do not commit it. Ollama normally needs no key. Some gateways also require provider-specific headers or `Authorization: Bearer`. |
| Model not found or 400 model error | `PRAXO_MODEL` | Use the exact model id served by the endpoint, not the package name or a display name. Pull the Ollama model first. |
| Request hangs | Endpoint, network, model size | Try a smaller model, check proxy/firewall settings, and increase the adapter timeout in the example. The live examples do not expose a separate timeout variable. |
| Python `urllib` or Node `http`/`fetch` hangs on loopback while `curl` or Python `http.client` succeeds | OS proxy/PAC, endpoint monitor, runtime | Confirm the endpoint with `curl` or `http.client`; check loopback proxy bypass and security software; try another runtime or a hosted endpoint. The Go example can isolate whether the endpoint itself works. |
| Model load fails with a CLIP or vision error | Model type, local memory, inference server | Use a non-vision tool-capable model such as `qwen2.5:0.5b`, or free memory and restart the local server. The failure is in the inference server, not PRAXO-CORE. |
| Model answers without a tool call | Prompt and model capability | Ask explicitly to use `get_time` and pass a `zone`. Small models may ignore tools or invent arguments. |
| Tool schema or argument error | `zone` parameter | Use a string timezone such as `UTC` or `Europe/Berlin`; do not pass a number or an empty object. |
| Policy denial | Allowed tool scope | The live example permits only `get_time`; a different tool is expected to be denied. Verify the denial path with the consumer starter. |
| PowerShell cannot find a command | Environment variable or quoting | Set `$env:PRAXO_BASE_URL` and `$env:PRAXO_MODEL`; use the commands from the language README. For Go, run with `$env:GOWORK = "off"`. |
| Windows path or build error | Toolchain and path | Run from the repository root or the example directory as documented; quote paths with spaces. C, C++, and Zig may need their documented compiler or SDK setup. |

The language examples use their adapter defaults for HTTP timeouts. Increase the
timeout in the example code when a local model is slow; do not add an
undocumented environment variable.

Common environment variables:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
export PRAXO_API_KEY=...   # hosted endpoints only
```

On PowerShell:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "llama3.2"
$env:PRAXO_API_KEY = "..."
```

Record the endpoint class, model id, package version, command, and observed
error when reporting a failure. Do not paste keys or tenant data.

The example is an integration starting point, not a production security profile.
Identity, durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
