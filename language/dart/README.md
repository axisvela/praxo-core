# PRAXO-CORE Dart Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
native Dart Core: an agent loop with tool registration and dispatch, policy
hooks, typed events, memory, checkpoints, context budgets, middleware, JSON
Schema validation, and plugin manifest parsing. It runs in-process and does not
require a hosted service.

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.1.1`
- Tier: core
- License: MIT
- Dependencies: Dart standard library only

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

## Layout

- `lib/` package source.
- `conformance/run.dart` vector runner.
- `api-snapshot.py` and `api/` public API snapshot.
- `test/run.dart` test suite.

## Release

Tag shape: `dart/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
