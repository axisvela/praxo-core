# PRAXO-CORE Dart Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
native Dart Core: an agent loop with tool registration and dispatch, policy
hooks, typed events, memory, checkpoints, context budgets, middleware, OTel and Harmovela sinks, MCP, retriever and synchronous delegation seams, JSON
Schema validation, and plugin manifest parsing. It runs in-process and does not
require a hosted service.

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.4.0`
- Tier: core
- License: MIT
- Dependencies: Dart standard library only
- Published on pub.dev as `praxo_core@0.1.1`

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/dart/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/dart/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/dart/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [pub.dev](https://pub.dev/packages/praxo_core/versions/0.2.0)

## Install

```bash
dart pub add praxo_core
```

## Scope

The Core implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, and the agent
loop. It includes a public API snapshot and a dependency-free test runner.

## Build and test

```bash
dart run conformance/run.dart
python api-snapshot.py --check
dart run test/run.dart
```

Run from the `dart/` directory, or use `dart language/dart/conformance/run.dart` from the
repository root.

## Quickstart

```dart
import 'package:praxo_core/praxo_core.dart';

void main() {
  final agent = Agent(AgentOptions(StaticModel('hello')));
  final result = agent.run(const Session(id: 'demo'), 'hello');
  print(result.output);
}
```

Tools register on the options object:

```dart
final registry = Registry();
registry.register(FuncTool('echo', 'Echo arguments', (arguments) => arguments));

final options = AgentOptions(StaticModel('hello'))
  ..tools = registry
  ..maxSteps = 8;
```

## OpenAI-Compatible Adapter

`OpenAICompatibleModel` maps Core requests to `POST {baseUrl}/chat/completions`,
including messages, tools, tool choice, assistant tool calls, token usage, and
provider HTTP errors (`PROVIDER_HTTP`). Streaming is not implemented.

```dart
final model = OpenAICompatibleModel(
  baseUrl: 'https://api.example.com/v1',
  model: 'provider-model-id',
  apiKey: Platform.environment['API_KEY'],
);
final response = await model.generateAsync(const Request(messages: [
  Message.text(roleUser, 'hello'),
]));
```

`generate` is synchronous for the existing `Model` seam; inject a synchronous
`transport` or use an `http` endpoint. `generateAsync` uses `dart:io`'s HTTP
client and supports `https`. Pass `transport` or `asyncTransport` in tests to
avoid network calls.

## Anthropic and Gemini Adapters

`AnthropicModel` and `GeminiModel` map the native Messages and generateContent
APIs. Both provide synchronous and asynchronous generation, injectable
transports, tool-call mapping, usage, and provider error handling.

```dart
final claude = AnthropicModel(
  model: 'claude-sonnet-4-5',
  apiKey: Platform.environment['ANTHROPIC_API_KEY'],
);
final gemini = GeminiModel(
  model: 'gemini-2.5-pro',
  apiKey: Platform.environment['GEMINI_API_KEY'],
);
```

## MCP Client

`McpClient` implements a stdio JSON-RPC MCP session with initialize, paginated
tool listing, tool calls, timeouts, cancellation notifications, and a
`StdioMcpTransport` backed by `Process.start`. Tests can implement
`McpTransport` directly.

## Harmovela Event Sink

`HarmovelaSink` implements the native `EventSink` seam. It posts each event to
`POST {baseUrl}/events` with the documented envelope. Supply `transport` to run
without network access; it receives `(baseUrl, path, body, headers)` and returns
a `HarmovelaResponse`. Supply `clock` to return `(seconds, nanos)` for
deterministic ids and timestamps.

```dart
final sink = HarmovelaSink(
  baseUrl: 'http://127.0.0.1:8790/aep/api',
  source: 'praxo-core',
  specVersion: '0.2',
);
final options = AgentOptions(StaticModel('hello'))..events = sink;
final result = Agent(options).run(const Session(id: 'demo'), 'hello');
```

A 2xx status is success. Any other status throws `PraxoError` with code
`HARMOVELA_HTTP`; a missing base URL throws `HARMOVELA_URL`. The synchronous
default transport supports `http` only; inject a transport for `https`. The sink
adds no authentication, retries, buffering, ordering, or exactly-once delivery.
Use HTTPS and caller-side filtering for sensitive event data.

## Layout

- `lib/` package source.
- `conformance/run.dart` vector runner.
- `api-snapshot.py` and `api/` public API snapshot.
- `test/run.dart` test suite.

## Release

Tag shape: `dart/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
