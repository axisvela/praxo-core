# PRAXO-CORE for Delphi and Free Pascal

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
native Delphi / Free Pascal Core: an in-process agent loop with tools, policy,
memory, events, checkpoints, context, and middleware helpers. It is implemented
in Object Pascal and does not call Go or another language Core.

Use it when an existing Delphi or Free Pascal application needs a governed
model/tool loop without adding an external runtime. It is not an HTTP user agent,
crawler, hosted agent service, or model provider. It includes native
OpenAI-compatible, Anthropic, and Gemini model adapters, including Anthropic and Gemini
SSE streaming, and a JSON-Lines process plugin host.

Current source is `delphi/v0.9.0`. It passes all eleven vector groups.

Local validation uses Free Pascal 3.2.2 on Windows i386. It does not establish
commercial Delphi compiler compatibility, Linux/macOS support, production
readiness, or a delivery date. The `0.9.0` OPM descriptor and submission archive
are available as [GitHub release assets](https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.9.0).
An OPM listing is not verified; GitHub assets do not establish OPM publication.
The CI recipe targets Free Pascal on Ubuntu.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/delphi/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/delphi/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/delphi/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/delphi/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [GitHub release (OPM listing unverified)](https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.9.0)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Representative Flows

- [Representative chain](language/go/examples/representative-chain/): deterministic MCP
  record, final-argument authorization, child delegation, OTel/Harmovela events,
  and an edited denial with zero effects.
- [Advanced delegation](language/go/examples/advanced-delegation/): parent/child scope and
  six governance negative checks.

## Build and Test

With Free Pascal and Python 3.10 or newer, from the repository root:

```bash
python language/delphi/run-tests.py
python language/delphi/api-snapshot.py --check
```

Set `FPC` or pass `--compiler /path/to/fpc` to select the compiler. Python only
launches the native build and validates source API/parity metadata. The test
programs and implementation run under Free Pascal. The runner covers all eleven
shared vector groups and verifies the contract version before running them.
See [SETUP.md](SETUP.md) for prerequisites and individual test commands.

The OPM descriptor is `praxo_core.lpk`. Build the submission archive and OPM
metadata with `python language/delphi/build_opm.py`; the outputs are written to
`language/delphi/build/opm/`.

To build manually from `language/delphi/`:

```bash
fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild praxo.pas
fpc -Mobjfpc -Scghi -O2 -Fu. -Futests -FEbuild tests/praxo_tests.lpr
./build/praxo_tests ../../spec
fpc -Mobjfpc -Scghi -O2 -Fu. -Futests -FEbuild tests/agent_tests.lpr
./build/agent_tests ../../spec
fpc -Mobjfpc -Scghi -O2 -Fu. -Futests -FEbuild tests/hitl_tests.lpr
./build/hitl_tests
fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild praxo_otel.pas
fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild praxo_retriever.pas
fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild praxo_delegation.pas
fpc -Mobjfpc -Scghi -O2 -Fu. -Futests -FEbuild tests/adapter_tests.lpr
./build/adapter_tests
```

## API

Add `language/delphi` to the compiler unit path and use:

```pascal
var
  data: TJSONData;
  call: TPraxoCall;
begin
  data := PraxoParseJSON('{"name":"echo","input":{"text":"hi"}}');
  try
    if PraxoParseToolCall(PraxoEncodeJSON(data), call) then
      Writeln(call.Name);
  finally
    data.Free;
  end;
end;
```

Public declarations are inventoried in [`api/0.6.0.txt`](api/0.6.0.txt).
The JSON node type is Free Pascal's `TJSONData` (`fpjson`), so consumers already
using `fpjson` can inspect results directly. `TPraxoCall.Input` is caller-owned.
`PraxoValidateManifest` returns an owned `TJSONObject` on success.

The separate `praxo_openai` unit provides an OpenAI-compatible adapter. It posts to `{baseURL}/chat/completions`, maps assistant content, tool
calls, usage, and finish reason, and exposes an injectable
`TPraxoOpenAITransport` for deterministic tests. Missing base URLs and non-2xx
responses raise `EPraxoProvider` with a `PROVIDER_HTTP` code. `GenerateStream`\nsets `stream: true`, parses SSE, reassembles content, fragmented tool calls,\nusage, and finish reason, and calls a delta hook. Set `OnDelta` in\n`TPraxoAgentOptions` to use it through the agent. The default transport uses `fphttpclient` without OpenSSL; for
HTTPS, include `opensslsockets` in the application or inject a TLS-capable
transport.

```pascal
var
  Adapter: TPraxoOpenAIAdapter;
  Messages: TJSONArray;
  Message, Response: TJSONObject;
begin
  Adapter := TPraxoOpenAIAdapter.Create('https://api.openai.com/v1', 'gpt-4o-mini');
  Adapter.APIKey := GetEnvironmentVariable('PRAXO_API_KEY');
  Messages := TJSONArray.Create;
  Message := TJSONObject.Create;
  Message.Add('role', 'user');
  Message.Add('content', 'Hello');
  Messages.Add(Message);
  try
    Response := Adapter.Generate(Messages);
    try
      // Response has content, toolCalls, inputTokens, and outputTokens.
      Writeln(Response.Get('content', ''));
    finally
      Response.Free;
    end;
  finally
    Messages.Free;
    Adapter.Free;
  end;
end;
```

The separate `praxo_agent` unit provides `PraxoRunAgent`,
`PraxoRunAgentSession`, and an abstract `TPraxoAgentHost`. Implement `Generate`,
`Invoke`, and `Emit` to connect a model, tools, and an event sink. Override
`EmitEvent` when event data is needed. `Generate` receives a borrowed message
array and must return an owned object with a string `content`, optional integer
`inputTokens` and `outputTokens`, and optional `toolCalls` array containing
objects with string `id`, nonempty string `name`, and object `arguments`.
`Invoke` receives borrowed arguments and returns an owned JSON value. The loop
frees returned objects and values; callbacks must not retain or mutate borrowed
data. Tool results are serialized as JSON in subsequent tool messages. Host
exceptions propagate, with a best-effort `run.failed` event. Budget and
malformed response errors use `EPraxoAgent.Code`; these local validation codes
are not wire codes. Nonpositive `MaxSteps` defaults to eight and nonpositive
`MaxTokens` is unlimited.

`PraxoRunAgentSession` accepts prior messages and returns the full updated
history in `Result.Messages`, which the caller frees. The legacy
`PraxoRunAgent` call keeps its existing signature and returns no history.
`TPraxoAgentOptions` carries `SessionId`, `InterruptOn`,
`OnInterruptDecision`, `OnInterrupt`, and an optional argument-aware
`Authorize` hook. Interrupt decisions are `approve`, `edit`, `reject`, and
`respond`; edited arguments are reauthorized before invocation. `tool.interrupt`
and `tool.call` expose their name and arguments to hosts that override
`EmitEvent`.

## Harmovela Event Sink

The `praxo_harmovela` unit posts `TPraxoEvent` values to
`POST {baseURL}/events` with the documented envelope (`spec_version`, `id`,
`type`, `source`, `created_at`, `payload`). It exposes an injectable
`TPraxoHarmovelaTransport` and a UTC nanosecond `TPraxoHarmovelaClock` so tests
need no network or wall clock.

```pascal
var
  Sink: TPraxoHarmovelaSink;
  Event: TPraxoEvent;
begin
  Sink := TPraxoHarmovelaSink.Create('http://127.0.0.1:8790/aep/api');
  try
    Event.Kind := 'tool.call';
    Event.SessionId := 's1';
    Event.RunId := 'run-1';
    Event.Data := TJSONObject.Create;
    try
      TJSONObject(Event.Data).Add('name', 'echo');
      Sink.Emit(Event);
    finally
      Event.Data.Free;
    end;
  finally
    Sink.Free;
  end;
end;
```

`Emit` accepts any 2xx response and raises `EPraxoHarmovela` with
`HARMOVELA_HTTP`, the status, and a 512-character body limit otherwise. The sink
has no authentication, retries, buffering, ordering, or exactly-once guarantee;
filter sensitive event data caller-side and use HTTPS for remote endpoints.

## OpenTelemetry Event Sink

The `praxo_otel` unit maps a `TPraxoEvent` to one OTLP/HTTP JSON span. It posts
`POST {endpoint}` with `content-type: application/json` through an injectable
`TPraxoOtelTransport`. `TPraxoOtelSink` requires an endpoint and raises
`EPraxoOtel` with `OTEL_URL` when it is empty. Any 2xx status succeeds; other
statuses raise `OTEL_HTTP` with the status and a 512-character body limit. Event
data is excluded by default; call `AllowDataKey` for each key to export. Trace
and span identifiers are deterministic 32- and 16-character hexadecimal strings
derived from the event. The sink has no OpenTelemetry SDK dependency.

```pascal
var
  Sink: TPraxoOtelSink;
  Event: TPraxoEvent;
begin
  Sink := TPraxoOtelSink.Create('http://127.0.0.1:4318/v1/traces');
  try
    Sink.AllowDataKey('name');
    Event.Kind := 'tool.call';
    Event.SessionId := 's1';
    Event.RunId := 'run-1';
    Event.Data := nil;
    Sink.Emit(Event);
  finally
    Sink.Free;
  end;
end;
```

## Retriever

The `praxo_retriever` unit provides the `TPraxoDocument` record, the
`TPraxoRetriever` callback, and `PraxoRetrieveDocuments`. The callback receives
a query and limit and returns documents whose `Metadata` value is caller-owned.
A negative limit raises `EPraxoRetriever` with `RETRIEVER_INVALID`.

```pascal
function Retrieve(const Query: UTF8String; Limit: Integer): TPraxoDocuments;
begin
  SetLength(Result, 1);
  Result[0] := PraxoDocument('doc-1', Query);
end;

Documents := PraxoRetrieveDocuments(@Retrieve, 'hello', 3);
```

## Subagent Delegation

The `praxo_delegation` unit provides a synchronous `TPraxoSubagentManager`.
Assign `Runner` and optionally `Clock`; `Run` validates the parent session and
agent identifiers (`SUBAGENT_INVALID`) and returns a task in `completed` or
`failed` state. A runner exception of type `EPraxoDelegation` preserves its
`Code`; other exceptions map to `SUBAGENT_ERROR`. There is no asynchronous
manager.

## Current Limits

- The verified target is Free Pascal 3.2.2 Windows i386. Other FPC targets and
  the proprietary Delphi compiler require separate testing.
- JSON input and output are bounded to 1,048,576 characters and nesting to 64.
  Tool-call input is bounded to 262,144 characters.
- `fpjson` is used for structure, but Unicode escapes are expanded before parsing
  to preserve supplementary code points on FPC 3.2.2. Strings are represented as
  UTF-8 on the verified Windows target; callers should use `UTF8String` for
  lossless non-ASCII data. The supplementary-code-point round-trip test is
  Windows-only; Linux CI currently covers the shared wire vectors but not that
  specific round-trip assertion.
- Numbers are finite doubles; large integers and exact decimal spellings may lose
  precision. Nonfinite values, malformed UTF-8, invalid escapes, duplicate
  manifest fields, and trailing JSON are rejected.
- Tool calls cover canonical JSON, XML-style, dotted tags, and dotted plain
  lines. DSML, invoke, todo, and skill-install formats are not implemented.
  Generated call IDs are not provided; governance metadata is returned in
  `TPraxoCall.Metadata`. Markup stripping is not an authorization control.
- Schema patterns accept a bounded anchored ASCII subset, not full RE2.
  Unsupported patterns raise `EPraxoSchema`. JSON Schema behavior follows the
  documented subset, including zero bounds treated as unset and ignored unknown
  keywords.
- Manifest checks validate declarations only. They do not verify signatures,
  establish trust, execute plugins, or enforce OS sandboxing. Duplicate-field
  rejection is stricter than the Go JSON decoder.
- The loop is synchronous, accepts caller-supplied prior history, executes tools
  serially, and checks tool scope and authorization before side effects. It lacks
  cancellation, asynchronous streaming, durable persistence, and other advanced
  Core features. Multiple tool calls are validated and executed sequentially,
  rather than all being prepared before invocation as in Go. `Emit` receives only
  the event type; override `EmitEvent` for event data. `praxo_core` provides
  memory, event sinks, checkpoints, lexical path policy, context compaction,
  PII/structured-output helpers, call limits, and tool selection; the agent loop
  does not automatically apply every opt-in helper.
- Core-local exceptions are not new shared wire error codes. Passing the eleven
  vector groups does not imply full Go feature parity or production readiness.
- `praxo_otel`, `praxo_retriever`, and `praxo_delegation` are optional seams.
  They do not add an OpenTelemetry SDK, vector database, asynchronous worker,
  persistence, or delivery guarantee.

The source is MIT; see [LICENSE](LICENSE). Free Pascal, its RTL, `fpjson`, and
`RegExpr` are separate toolchain components, not vendored code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/delphi.md), and
[implementation support](../../docs/languages/support.md).


## Tutorials and Reference Applications

Language-specific scenario tutorials and reference applications for Delphi / Free Pascal.

### Scenario Tutorials

| Tutorial | What it shows |
| --- | --- |
| [hvac-settings](https://github.com/axisvela/praxo-core/tree/main/language/delphi/Tutorial/hvac-settings) | A bounded first slice of BE-02, not a building-management system. It reads a fixed building environment and drafts a review-only settings plan using the source Delphi/Free Pasca... |
| [legacy-migration](https://github.com/axisvela/praxo-core/tree/main/language/delphi/Tutorial/legacy-migration) | A bounded first slice of [SE-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an automatic production migration. It inventories fixed legacy modu... |
| [rpa-reconciliation](https://github.com/axisvela/praxo-core/tree/main/language/delphi/Tutorial/rpa-reconciliation) | A bounded first slice of [OP-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a production RPA platform. It reconciles a fixed purchase order and... |
| [tax-review](https://github.com/axisvela/praxo-core/tree/main/language/delphi/Tutorial/tax-review) | A bounded tax-planning tutorial. It reads a fixed ledger, computes taxable income and tax due, then drafts a review-only filing. No filing is submitted and no tax advice is given. |

Index: [language/delphi/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/delphi/Tutorial).

### Reference Applications

No accepted end-to-end reference application is recorded for this language yet. Candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).

Planning context: [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/), [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), and [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/). Chinese: [教程计划](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/), [候选场景](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/), [教程目录](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/).

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>
- LinkedIn: <https://www.linkedin.com/company/axisvela/>
- Facebook: <https://www.facebook.com/profile.php?id=61596905732406>
- YouTube: <https://www.youtube.com/@axisvela>
- Discord: <https://discord.com/channels/1575163993767809064/1575164343148875977>
- GitHub Discussions: <https://github.com/axisvela/praxo-core/discussions>
- GitHub Issues: <https://github.com/axisvela/praxo-core/issues>
- Documentation: <https://axisvela.github.io/praxo-core/>
- Architect: <https://axisvela.architect.pub>

