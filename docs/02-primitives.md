# PRAXO-CORE Primitives

| Package | Contract | Typical adapter |
| --- | --- | --- |
| `pkg/model` | `Model.Generate` | PRAXOVELA provider router |
| `pkg/tool` | `Tool`, `Registry` | Janus Gateway tools |
| `pkg/memory` | `Store.Put/Search` | Mnemovela |
| `pkg/event` | `Sink.Emit` | Harmovela / Argus Trace |
| `pkg/policy` | `Hook.Authorize` | AEGIVELA / Archon Guard |
| `pkg/sandbox` | `Sandbox.Run` | Vulcan Forge |
| `pkg/scheduler` | `Scheduler.Add/Remove/List`; cron engine extracted from PRAXOVELA | PRAXOVELA durable scheduler |

## Tool Contract

A tool has a name, description, and `Invoke(ctx, args)`. Tool specs are exposed
to the model through the registry. Arguments are JSON-compatible maps.

## Memory Contract

Memory is typed by frame: event, decision, experience, procedure, workspace
state, constraint, intention. The framework does not dictate retention or
admission; adapters do.

## Event Contract

Events are lifecycle facts, not logs. Consumers may publish them to Harmovela
or persist them in Argus Trace.

## Policy Contract

Every model generation and tool invocation can be authorized. Denial fails
closed. The framework does not implement policy; it enforces the hook result.

## Scheduler Contract

The framework defines schedules. A runtime owns durable firing and execution.
The scheduling contract is intentionally separate from the agent loop.
