# PRAXO-CORE for Objective-C

Objective-C is a native Core implementation with source tag `objc/v0.4.0`. It
passes all eleven shared vector groups and includes the native
agent loop, context compaction, memory store, path policy, checkpoint
allowlist, tool selection, tool-call parsing, and opt-in PII redaction,
structured output validation, and call limits. Vector
coverage does not establish full Core parity or production readiness.

The Core does not call Go or another language runtime. It includes
OpenAI-compatible, Anthropic, and Gemini model adapters, MCP and Harmovela
transport seams, and OpenTelemetry, retriever, and synchronous delegation
seams; a plugin host remains outside the declared Core scope.

Local validation uses clang 21.1.8 with GNUstep Base 1.31.1 and lld on Windows.
A macOS CI job runs the Apple Foundation build. Local Apple Foundation, release
review, package publication, and a delivery date are not claimed.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/objc/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/objc/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/objc/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/objc/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: Source
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761)

## Build And Test

From the repository root with Python 3.10 or newer:

```bash
python language/objc/api-snapshot.py --check
python language/objc/run-tests.py
```

`run-tests.py` also checks the API snapshot before compiling. Set `CLANG` or pass
`--compiler /path/to/clang`. On Windows, the GNUstep runtime directory must be on
`PATH` so the test executable can load `gnustep-base` and the Objective-C
runtime. The runner links GNUstep builds with lld because the GNU ld PE/COFF
path discards the GNUstep selector COMDAT sections.

To build manually on macOS from `language/objc/`:

```bash
clang -fobjc-arc -fblocks -I. -o build/praxo_tests \
  PraxoJSON.m PraxoJsonSchema.m PraxoPlugin.m PraxoWire.m \
  PraxoCore.m PraxoAgent.m tests/main.m tests/correlation.m tests/middleware.m \
  -framework Foundation
build/praxo_tests ../../spec
```

For a GNUstep build, use `-fobjc-runtime=gnustep-2.0 -fuse-ld=lld` and link
`-lgnustep-base -lobjc -lstdc++`.

The complete local environment procedure, including manual clang and GNUstep
installation, is in [SETUP.md](SETUP.md).

## API

```objc
#import "PraxoCore.h"

NSDictionary *call = PXRParseToolCall(
    @"<tool_call name=\"echo\">{\"text\":\"hi\"}</tool_call>", nil);
NSString *text = PXRStripToolCallMarkup(content);
NSArray<NSString *> *paths = PXRValidateSchema(schema, data);
NSDictionary *manifest = PXRParseManifest(raw, &error);

NSMutableDictionary *options = PXRAgentOptionsCreate(PXRModelCreateStatic(@"hello"));
NSError *runError = nil;
NSDictionary *result = PXRAgentRun(options, PXRSessionCreate(@"s1", @[]), @"hello", &runError);

PXRModelGenerate model = PXROpenAIModelCreate(
    @"https://api.openai.com/v1", @"gpt-4o-mini", apiKey, nil);
```

`PXROpenAIModelCreate` returns a model callback that posts to
`{baseURL}/chat/completions`, maps assistant content, tool calls, usage, and
finish reason, and injects `PXROpenAITransport` for deterministic tests.
Missing base URLs and non-2xx responses produce a `PROVIDER_HTTP` error; invalid
tool arguments produce `PROVIDER_JSON`. Streaming is not implemented.

Public declarations are inventoried in [`api/0.4.0.txt`](api/0.4.0.txt).
Agent events use the supplied session's `id` and a UUID-based run ID; the
existing event sink callback is unchanged.
Set `options[@"toolSelection"]` to a set from `PXRToolSelectionCreate` to
advertise and permit only selected tool names. An empty set denies all tools;
omitting the option preserves unrestricted tool behavior. A call to an
unselected name fails with `AGENT_TOOL_NOT_SELECTED` before invocation.
Set `options[@"pii"]` to `@YES` to redact model-bound message content and
content-block text, and recursively redact tool results, using the built-in
email, SSN, credit-card, and US-style phone rules. Other block fields and historical tool-call arguments remain unchanged.
Tool invocations and events receive original arguments, and final output is not
redacted. Redaction is not a comprehensive privacy or logging control.
Set `options[@"structuredOutput"]` to a `PXRStructuredOutputCreate` configuration
to validate and optionally repair the final output; failures return
`AGENT_STRUCTURED_OUTPUT` without completing the run. Set
`options[@"modelCallLimit"]` and `options[@"toolCallLimit"]` to positive numbers
to bound invocations independently per run. Values at or below zero are unlimited.
These options are disabled by default.
The parser returns `nil` when the content is not a recognized call or the
manifest is invalid. Schema validation returns error paths. Core-local
`PXRWireErrorDomain` and `PXRCoreErrorDomain` codes are not new shared wire
error codes.

## Anthropic and Gemini Adapters

`PXRAnthropicGenerate` and `PXRGeminiGenerate` provide native Messages and
generateContent mappings with the same `PXROpenAITransport` seam.

```objc
#import "PraxoAnthropic.h"
#import "PraxoGemini.h"
```

Both map tool calls, tools schemas, usage, and provider errors.

## Harmovela Event Sink

```objc
#import "PraxoHarmovela.h"

PXRHarmovelaSink sink = PXRHarmovelaSink(
    @"http://127.0.0.1:8790/aep/api", @"praxo-core", @"0.2", nil, nil);
options[@"events"] = sink;
```

`PXRHarmovelaSend` posts to `{baseURL}/events` with
`content-type: application/json` and the `spec_version`, `id`, `type`,
`source`, `created_at`, and merged `payload` envelope. Inject
`PXRHarmovelaTransport` and `PXRHarmovelaClock` for deterministic tests. A 2xx
status is success; any other status is a `HARMOVELA_HTTP` error with the status
and a bounded response body.

The sink adds no authentication, retries, buffering, ordering, or
exactly-once-delivery guarantee. Apply caller-side filtering because event data
may contain sensitive content, and use HTTPS for remote endpoints.

## OpenTelemetry, Retriever, and Delegation Seams

```objc
#import "PraxoOtel.h"
#import "PraxoRetriever.h"
#import "PraxoDelegation.h"

PXREventSink otel = PXROtelSink(
    @"http://127.0.0.1:4318/v1/traces", @"praxo-core", @[@"name"], nil, nil);
```

`PXROtelSend` maps one Core event to one OTLP/HTTP span over an injected
`PXROtelTransport`. Event data is excluded unless its key is allowlisted; a
non-2xx response is an `OTEL_HTTP` error with a bounded response body. Trace and
span identifiers are deterministic for the event and clock value.

`PXDocument` and `PXRetriever` provide a document/query/limit seam through
`PXRetrieveDocuments`; a negative limit is `RETRIEVER_INVALID`.

`PXRSubagentRun` runs a caller-supplied `PXRSubagentRunner` synchronously and
returns a terminal completed or failed `PXRSubagentTask`. A runner failure
preserves its error code. It does not provide an asynchronous manager, durable
queue, or cross-process worker.

## Current Limits

- The verified local target is Windows clang + GNUstep; the macOS CI job covers
  Apple Foundation. Windows support depends on the GNUstep package and lld.
- JSON is bounded to 1,048,576 characters and nesting to 64. Invalid UTF-8,
  malformed escapes, duplicate object keys, and trailing JSON are rejected.
  Numbers use Foundation JSON numbers, so large integers and exact decimal
  spellings may lose precision.
- Tool calls cover canonical JSON, XML-style, dotted tags, and dotted plain
  lines. DSML, invoke, todo, and skill-install formats are not implemented.
  Generated call IDs are not provided. Markup stripping is not an authorization
  control or security sanitizer.
- Schema patterns use a bounded ASCII `NSRegularExpression` subset, not full
  RE2. Zero bounds are treated as unset, additional properties are allowed, and
  unknown keywords are ignored.
- Path checks are lexical and confined by separator boundaries. Relative paths
  retain unmatched parent components and are compared as written, not resolved
  against a working directory. Checks do not resolve symlinks, filesystem
  aliases, or replace operating-system sandboxing.
- Manifest checks validate declarations only. They do not verify signatures,
  establish trust, execute plugins, or enforce OS sandboxing.
- The OpenAI-compatible adapter is non-streaming. Streaming wire encodings and
  plugin hosts are not part of this Core.

The source is MIT; see [LICENSE](LICENSE). Clang, GNUstep, and other toolchain
components are separate projects, not vendored code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/objc.md), and
[implementation support](../../docs/languages/support.md).
