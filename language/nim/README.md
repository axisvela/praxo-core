# PRAXO-CORE for Nim

Nim is a native Core implementation targeting the PRAXO-CORE contract. It
passes all eleven shared vector groups with `Nim 2.2.12` and includes the native
agent loop, context compaction, memory store, path policy, checkpoint
allowlist, tool-call parsing, and opt-in agent tool selection, PII redaction,
structured output, and call limits. Vector coverage does not establish full
Core parity or production readiness.

The SDK does not call Go or another language runtime. It has no provider
adapter or plugin host; those remain outside the declared Core scope.

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

Set `options.toolSelection = some(toolSelection(@["echo"]))` (import
`std/options`) to advertise only selected tools and reject calls to other
registered tools with `AGENT_TOOL_NOT_SELECTED`. An empty selection denies all
tools; leaving the option unset advertises and permits all registered tools.

Set `options.pii = true` to redact message content and text blocks sent to the
model and recursively redact string values in tool results. The existing PII
helper covers email, SSN, and credit card patterns; it is not a complete privacy
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

Public declarations are inventoried in [`api/0.1.0.txt`](api/0.1.0.txt).

## Current Limits

- Verified with `Nim 2.2.12` and MSYS2 `gcc 15.2.0` on Windows. Other Nim
  releases, other C compilers, and remote CI are not yet verified.
- JSON uses `std/json`. Invalid JSON and trailing data are rejected. Duplicate
  object keys are not a declared vector and should not be treated as a security
  boundary.
- Schema patterns support a bounded subset (anchors, literals, `.`, character
  classes, `\d`, `\w`, `\s`, and `*`, `+`, `?`). Unsupported constructs are
  rejected by the subset matcher; the SDK does not link PCRE at runtime.
- Tool calls cover canonical JSON, XML-style, dotted tags, and dotted plain
  lines. Generated call IDs are not provided. Markup stripping is not an
  authorization control or sanitizer.
- Path checks are lexical and confined by separator boundaries. They do not
  resolve symlinks or replace operating-system sandboxing.
- Provider adapters, streaming wire encodings, and plugin hosts are not part of
  this SDK.

The source is MIT; see [LICENSE](LICENSE). Nim, MinGW, and other toolchain
components are separate projects, not vendored code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/nim.md), and
[implementation support](../../docs/languages/support.md).
