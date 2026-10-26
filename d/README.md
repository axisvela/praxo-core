# PRAXO-CORE D SDK

D implementation of the PRAXO-CORE agent contract. The normative contract is
[`spec/`](../spec/README.md); Go remains the reference implementation.

- `SPEC_VERSION`: `0.2.0`
- SDK version: `0.1.0`
- Tier: core
- License: MIT
- Dependencies: D standard library only

## Scope

The SDK implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, and the agent
loop. It includes a public API snapshot and a test runner.

## Build and test

```bash
mkdir -p build
dmd -i -I source -O -release source/conformance.d -of=build/conformance
./build/conformance
dmd -i -I source -O -release source/tests.d -of=build/tests
./build/tests
python api-snapshot.py --check
```

## Quickstart

```d
import praxo.agent;
import praxo.models;

void main() {
    auto options = new AgentOptions(new StaticModel("hello"));
    auto result = runAgent(options, Session("demo"), "hello");
    writeln(result.output);
}
```

Tools register on the options object:

```d
auto registry = new Registry();
registry.register(new FuncTool("echo", "Echo arguments", (arguments) => arguments));
options.tools = registry;
```

## Layout

- `source/praxo/` package modules.
- `source/conformance.d` vector runner.
- `source/tests.d` test runner.
- `api-snapshot.py` and `api/` public API snapshot.

## Release

Tag shape: `d/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
