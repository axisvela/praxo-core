# Structured Output by Language

The published-package processor examples turn free text into validated JSON.
The [language coverage matrix](../getting-started/language-coverage.md) lists
structured-output source entries for thirty-one languages, not thirty-one
equivalent processors or verified application tutorials.

Five primary SDKs ship published-package examples:

- [Python](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/structured-output)
- [TypeScript](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/structured-output)
- [Java](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/structured-output)
- [C#](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/structured-output)
- [Rust](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/structured-output)

The remaining SDKs ship deterministic source-mode examples under
`language/<language>/examples/structured-output`. Go keeps its reference recipe
under `examples/recipes/structured-output-go`.

The processor examples validate `title`, `summary`, and `tags`. Source-mode
mechanism checks may instead validate a smaller schema (for example, C checks
`name`) without calling a model. Running a schema check is not evidence of a
model-to-application integration.

## Schema

```json
{
  "type": "object",
  "required": ["title", "summary", "tags"],
  "properties": {
    "title": { "type": "string" },
    "summary": { "type": "string" },
    "tags": { "type": "array", "items": { "type": "string" } }
  }
}
```

## Published-Package Examples

### Python

```bash
cd language/python/examples/structured-output
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python summarize.py "Quarterly status: all checks green."
```

Deterministic test:

```bash
.venv/bin/python -m unittest test_summarize.py -v
```

The example installs published PyPI `praxo-core==0.9.0`.

### TypeScript

```bash
cd language/typescript/examples/structured-output
npm install
npm start -- "Quarterly status: all checks green."
npm test
```

The example installs published npm `@axisvela/praxo-core@0.8.0`.

### Java

```bash
cd language/java/examples/structured-output
mvn -q compile exec:java -Dexec.args="Quarterly status: all checks green."
mvn -q test
```

The example resolves Maven Central `com.axisvela:praxo-core:0.9.0`.

### C#

```bash
cd language/csharp/examples/structured-output
dotnet run -- "Quarterly status: all checks green."
dotnet run -- --test
```

The example installs published NuGet `Praxo.Core==0.9.1`.

### Rust

```bash
cd language/rust/examples/structured-output
cargo run
```

The deterministic run validates a valid summary and rejects output that omits
required fields. The example uses published crates.io `praxo-core==0.9.1`.

## Go Reference Recipe

```bash
cd examples/recipes/structured-output-go
GOWORK=off go test -mod=readonly -run 'Structured|Schema|Arguments|ResponseFormat' -v ./...
```

From the repository root, the published-package check is:

```bash
python scripts/test_go_structured_output_recipe.py -v
```

The Go recipe also proves that invalid tool arguments are rejected before the
tool effect and that `model.ResponseFormat` carries the same schema.

## Source-Mode Examples

Source-mode examples use the repository implementation and do not install a
package. Build the Core first when the language requires it, then run the
example from the repository root. Each example prints a language-specific
`structured output example passed` line and exits nonzero when valid output is
rejected or invalid output is accepted.

| Language | Run command |
| --- | --- |
| C | `gcc -std=c11 -I language/c/include language/c/examples/structured-output/main.c language/c/build/libpraxo_core.a -lm -o build/c-structured-output && ./build/c-structured-output` |
| C++ | `g++ -std=c++20 -I language/cpp/include language/cpp/examples/structured-output/main.cpp language/cpp/build/libpraxo_cpp.a -o build/cpp-structured-output && ./build/cpp-structured-output` |
| COBOL | `python language/cobol/examples/structured-output/build.py` |
| D | `dmd -i -Ilanguage/d/source -run language/d/examples/structured-output/structured_output.d` |
| Dart | `dart language/dart/examples/structured-output/structured_output.dart` |
| Delphi / Free Pascal | `fpc -Mobjfpc -Fulanguage/delphi language/delphi/examples/structured-output/structured_output.pas && ./structured_output` |
| Elixir | `elixir -pa language/elixir/build/ebin language/elixir/examples/structured-output/structured_output.exs` |
| Erlang | `escript language/erlang/examples/structured-output/structured_output.escript` |
| Fortran | `python language/fortran/examples/structured-output/run.py` |
| Haskell | `runghc -ilanguage/haskell/src language/haskell/examples/structured-output/structured_output.hs` |
| Julia | `julia language/julia/examples/structured-output/structured_output.jl` |
| Lua | `lua language/lua/examples/structured-output/structured_output.lua` |
| MATLAB / Octave | `octave-cli --path language/matlab-octave-core --path language/matlab/examples/structured-output --eval structured_output_example` |
| Nim | `nim r --path:language/nim/src language/nim/examples/structured-output/structured_output.nim` |
| Objective-C | `clang -fobjc-arc -Ilanguage/objc/src language/objc/examples/structured-output/structured_output.m language/objc/src/PraxoJsonSchema.m language/objc/src/PraxoJSON.m -framework Foundation -o build/objc-structured-output && ./build/objc-structured-output` |
| OCaml | `ocaml language/ocaml/examples/structured-output/structured_output.ml` |
| Perl | `perl language/perl/examples/structured-output/structured_output.pl` |
| PHP | `php language/php/examples/structured-output/structured_output.php` |
| PowerShell | `pwsh -NoProfile -File language/powershell/examples/structured-output/structured_output.ps1` |
| R | `Rscript language/r/examples/structured-output/structured_output.R` |
| Ruby | `ruby -I language/ruby/lib language/ruby/examples/structured-output/structured_output.rb` |
| Swift | `swift run --package-path language/swift praxo-structured-output-example` |
| V | See the V command below the table. |
| Zig | `zig build-exe language/zig/examples/structured-output/structured_output.zig --dep json --dep jsonschema -Mroot=language/zig/examples/structured-output/structured_output.zig -Mjson=language/zig/src/json.zig -Mjsonschema=language/zig/src/jsonschema.zig -femit-bin=build/zig-structured-output && ./build/zig-structured-output` |

Core build prerequisites:

```bash
# C
cmake -S language/c -B language/c/build && cmake --build language/c/build

# C++
cmake -S language/cpp -B language/cpp/build && cmake --build language/cpp/build

# Elixir
mkdir -p language/elixir/build/ebin
elixirc -o language/elixir/build/ebin language/elixir/lib/praxo/*.ex language/elixir/lib/praxo/adapters/*.ex
```

```bash
# V
v -path "language/v|@vlib|@vmodules" language/v/examples/structured-output/structured_output.v
```

Octave reuses the MATLAB example through the shared
`language/matlab-octave-core` implementation.

## Prototype Walkthrough: Python Structured-Output Processor

This is a complete first prototype for a primary SDK. It turns one free-text
input into validated JSON and fails closed when the model omits required fields.

1. Create an application directory and install the published package:

```bash
python -m venv .venv
.venv/bin/python -m pip install "praxo-core==0.9.0"
```

2. Copy the tested schema and agent setup from
   [`language/python/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/structured-output).
   Keep the explicit policy allowlist and `StructuredOutput` middleware.

3. Run the deterministic model first:

```bash
.venv/bin/python summarize.py "Quarterly status: all checks green."
```

4. Run the deterministic rejection test. A response missing `summary` or
   `tags` must raise instead of returning partial JSON:

```bash
.venv/bin/python -m unittest test_summarize.py -v
```

5. Replace the fixture model with the OpenAI-compatible adapter only after the
   deterministic path passes. Keep the same schema and policy; do not remove the
   validation layer when moving to a real endpoint.

6. Record the package version, endpoint class, model name, schema version, and
   the command output. This is a local prototype, not a production service:
   identity, durable storage, retries, effect verification, and isolation remain
   application responsibilities.

## Prototype Walkthrough: TypeScript Structured-Output Processor

1. Create an application directory and install the published package:

```bash
npm init -y
npm install --save-exact @axisvela/praxo-core@0.8.0
```

2. Copy the schema, fixture model, policy, and `StructuredOutput` setup from
   [`language/typescript/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/structured-output).

3. Run the deterministic prototype:

```bash
npm start -- "Quarterly status: all checks green."
npm test
```

4. The test must reject a response that omits `summary` or `tags`; do not treat
   a parsed object as valid without schema validation.

5. Replace the fixture model with `OpenAICompatibleModel` only after the
   deterministic test passes. Keep the same schema, allowlist, and policy.
   Record the package version, endpoint class, model name, and command output.

## Other Prototype Paths

Inspect the schema and program under each language's
`examples/structured-output` directory before running it. First build or install
the required Core and run its acceptance/rejection assertions. A schema-only
mechanism needs a model and application integration before it is a processor;
adding a provider adapter alone does not establish that integration.

Java and C# have separate deterministic test modes and live run commands; Rust
uses a deterministic model in its default example. The
Go recipe validates both structured output and tool arguments. Source-mode
examples such as Ruby, PHP, Elixir, Lua, C, C++, Fortran, COBOL, Erlang, Dart,
Perl, Julia, Swift, Haskell, OCaml, D, Nim, Zig, V, Delphi, PowerShell, MATLAB,
Octave, and Objective-C show the same accept/reject behavior without a provider
endpoint.

For every language, record the package or source revision, endpoint class, model
name, schema version, commands, and output. Keep identity, durable storage,
retries, effect verification, and isolation in the application.

## Live Endpoint

The runnable published-package commands use an OpenAI-compatible endpoint:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
# export PRAXO_API_KEY=...   # hosted endpoints only
```

On PowerShell:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "llama3.2"
```

Source-mode examples that do not ship a provider adapter validate the schema
only. Wire a provider adapter behind the same model seam before claiming a live
endpoint path.

## What the Examples Prove

- the package is installed from a registry where a published example exists;
- the model adapter is configured from environment variables where supported;
- the processor examples validate final JSON against their schema;
- fixture-model checks exercise those integrations without a live endpoint;
- schema-only source examples exercise their own smaller validation cases.

They do not prove model quality, schema completeness, provider structured-output
support, or production behavior. Keep the final schema validation in the
application even when a provider supports structured output natively.

## Related

- [Examples](../getting-started/examples.md)
- [Language Coverage](../getting-started/language-coverage.md)
- [Live Model Golden Path](../getting-started/live-model-golden-path.md)
- [Application integration checklist](application-integration-checklist.md)
- [Consumer test template](consumer-test-template.md)
