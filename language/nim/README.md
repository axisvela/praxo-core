# PRAXO-CORE for Nim

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
native Nim Core with source tag `nim/v0.1.1`. It passes all eleven shared vector
groups with `Nim 2.2.12` and includes the native agent loop, context compaction,
memory store, path policy, checkpoint allowlist, tool-call parsing, and opt-in
agent tool selection, PII redaction, structured output, and call limits. Vector
coverage does not establish full Core parity or production readiness.

The Core does not call Go or another language runtime. It includes an optional
OpenAI-compatible, Anthropic, and Gemini model adapters; plugin hosts remain
outside the declared Core scope.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/nim/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/nim/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/nim/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [Nimble/nim-lang packages](https://github.com/axisvela/praxo-core-nim)

## Install

The Nimble package is mirrored from `axisvela/praxo-core-nim`, which keeps the
root `praxo_core.nimble` and `src/` tree required by Nimble and nimpkgs:

```bash
nimble install praxo_core
```

## Build And Test

From the repository root with Nim and a C compiler on `PATH`:

```bash
python language/nim/api-snapshot.py --check
nim c --path:language/nim/src --hints:off --out:build/praxo-nim-conformance.exe language/nim/conformance/run.nim
./build/praxo-nim-conformance.exe
nim c --path:language/nim/src --hints:off --out:build/praxo-nim-tests.exe language/nim/tests/run_tests.nim
./build/praxo-nim-tests.exe
```

On Linux omit the `.exe` suffix. The complete local environment procedure,
including manual Nim and MinGW installation, is in [SETUP.md](SETUP.md).

## API

```nim
import praxo

let call = parseToolCall("""<tool_call name="echo">{"text":"hi"}</tool_call>""")
assert call.isSome
assert call.get().name == "echo"

let schema = parseJsonText("""{"type":"string","pattern":"^a+$"}""")
assert validateSchema(schema, %"aaa").len == 0
```

Consumers can connect a synchronous model implementation with a closure:

```nim
let model = callbackModel(proc(request: Request): Response =
  return newResponse(newMessageAssistant("Hello"))
)
let result = runAgent(newAgentOptions(model), newSession("s1"), "Hi")
```

The callback receives the current messages and tool specifications on each
step. It returns a response including any tool calls and usage. Catchable
errors propagate through the agent and can trigger `fallbackModel`.

For an OpenAI-compatible endpoint, use the non-streaming adapter:

```nim
let adapter = newOpenAICompatible(
  baseUrl = "https://api.openai.com/v1",
  model = "gpt-4o-mini",
  apiKey = getEnv("PRAXO_API_KEY"),
)
let model = openaiModel(adapter)
let result = runAgent(newAgentOptions(model), newSession("s1"), "Hi")
```

The adapter maps tool calls, usage, and `tool_choice`. It accepts an injected
`Transport` for deterministic tests. Streaming is not implemented.

Set `options.toolSelection = some(toolSelection(@["echo"]))` (import
`std/options`) to advertise only selected tools and reject calls to other
registered tools with `AGENT_TOOL_NOT_SELECTED`. An empty selection denies all
tools; leaving the option unset advertises and permits all registered tools.

Set `options.pii = true` to redact message content and text blocks sent to the
model and recursively redact string values in tool results. The existing PII
helper covers email, SSN, credit card, and US-style phone patterns; it is not a complete privacy
filter. Tool arguments, events, and final output are not redacted. Original
session messages are not modified.

Set `options.structuredOutput = some(structuredOutput(schema, maxRepairs, repairer))`
to validate the final output and optionally repair it using the existing helper.
Invalid output fails with `AGENT_STRUCTURED_OUTPUT` rather than completing.
The optional repairer is a synchronous closure and is not a model call.

Set `options.modelCallLimit` and `options.toolCallLimit` to positive values to
limit calls per run. Zero or negative values leave the corresponding limit
unbounded. Limits are checked before invoking the model or tool and reset for
each run; a fallback model counts as one agent model call.

Public declarations are inventoried in [`api/0.1.1.txt`](api/0.1.1.txt).

## Anthropic and Gemini Adapters

`newAnthropicCompatible` and `newGeminiCompatible` provide native model adapters
for the Messages and generateContent APIs. Both accept an injected transport for
deterministic tests.

```nim
let claude = newAnthropicCompatible("https://api.anthropic.com", "claude-sonnet-4-5", apiKey = "ak")
let gemini = newGeminiCompatible("https://generativelanguage.googleapis.com", "gemini-2.5-pro", apiKey = "gk")
```

## Harmovela Event Sink

`newHarmovelaSink` implements the event sink seam and posts to
`{baseUrl}/events`.

```nim
let events = newHarmovelaSink(
  baseUrl = "http://127.0.0.1:8790/aep/api",
  source = "praxo-core",
)
options.events = events
```

It accepts an injected `HarmovelaTransport` and `HarmovelaClock` for
deterministic tests. A 2xx status is success; other statuses raise
`HARMOVELA_HTTP` with a bounded body. The sink adds no authentication, retries,
buffering, ordering, or exactly-once delivery. Use HTTPS and filter sensitive
event data first.

## Current Limits

- Verified with `Nim 2.2.12` and MSYS2 `gcc 15.2.0` on Windows. Other Nim
  releases and other C compilers are not verified; Linux CI runs the same suite.
- JSON uses `std/json`. Invalid JSON and trailing data are rejected. Duplicate
  object keys are not a declared vector and should not be treated as a security
  boundary.
- Schema patterns support a bounded subset (anchors, literals, `.`, character
  classes, `\d`, `\w`, `\s`, and `*`, `+`, `?`). Unsupported constructs are
  rejected by the subset matcher; the Core does not link PCRE at runtime.
- Tool calls cover canonical JSON, XML-style, dotted tags, and dotted plain
  lines. Generated call IDs are not provided. Markup stripping is not an
  authorization control or sanitizer.
- Run IDs combine process time, nanoseconds, and a process-local sequence. They
  are not cross-process unique.
- Path checks are lexical and confined by separator boundaries. They do not
  resolve symlinks or replace operating-system sandboxing.
- Provider adapters, streaming wire encodings, and plugin hosts are not part of
  this Core.

The source is MIT; see [LICENSE](LICENSE). Nim, MinGW, and other toolchain
components are separate projects, not vendored code.

See [PUBLISHING.md](PUBLISHING.md) for the Nimble release flow, and
[language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/nim.md), and
[implementation support](../../docs/languages/support.md).
