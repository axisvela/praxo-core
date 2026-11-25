# C++ AI Industrial Edge Agent (AI-native reference application)

A C++ edge CLI where the agent drives the primary device-diagnosis workflow: an
operator submits an incident intent, the agent reads application-owned device
telemetry through a `GatewayAdapter`, diagnoses the condition, and drafts a
review-only maintenance action. The agent never writes to the device.

This is the AI-native C++ reference application. There is no traditional
application precursor.

## Why this language and runtime?

- **Selection basis:** C++ is common in industrial gateways, embedded hosts, and
  performance-sensitive applications that already own a device SDK or fieldbus
  adapter.
- **Demonstrated fit:** A native CLI, an application-owned adapter, governed
  tools, and a model trace exercise the Core seam without a second runtime.
- **Choose when:** Adding a bounded diagnosis/review action to an existing C++
  device or industrial application.
- **Do not choose when:** Direct device-SDK code or a simple deterministic runbook
  already solves the task, or when another host provides the same boundary with
  less integration effort.
- **Evidence limit:** Fixture adapter and deterministic model. The live path is
  not implemented because the C++ Core OpenAI-compatible adapter requires an
  application-supplied HTTP transport; no TLS transport is included.

## AI-native workflow

1. Run the CLI with a tenant, device id, and incident intent.
2. The agent reads telemetry through `GatewayAdapter`.
3. The model writes a diagnosis and rationale and drafts a review-only action.
4. The report returns `executions=0`.
5. An operator approves and performs any device action outside the agent.

If the model is removed, the primary gateway workflow disappears.

## Where is the LLM reasoning?

The deterministic tests use a scripted model. They verify the harness, policy,
failure paths, and trace shape, not LLM reasoning.

In a live path the model would choose tools/arguments and write the diagnosis and
rationale; `agent_trace` records tool calls and model output, and `model` would be
`"live"`. This revision does not include an HTTP transport for the Core
OpenAI-compatible adapter, so no C++ live run is recorded.

## Host integration

| Boundary | Where |
| --- | --- |
| CLI entry | `application/main.cpp` |
| Device adapter | `GatewayAdapter`, `FixtureGateway` |
| Tools and policy | `application/main.cpp` |
| Trace | `TracingModel` |
| Tests | `--test` entry |

Identity, device transport, approvals, and effect reconciliation remain
application-owned.

## Tools and policy

| Tool | Effect | Policy |
| --- | --- | --- |
| `read_device` | Read-only telemetry | Device must be `device-100` |
| `draft_maintenance` | Saves a model-written review-only remediation | `review_remediation` plus diagnosis/rationale |
| `execute_remediation` | Would execute remediation | Always denied in the agent path |

A `Remediate now` or `Execute remediation` intent is denied before telemetry read,
drafting, or execution.

## Build and test

The target uses the local C++ Core source; it is not a package-registry install.

```bash
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build --target praxo-cpp-ai-edge-application
./language/cpp/build/bin/praxo-cpp-ai-edge-application --test
```

Expected: five checks pass, covering the review-only package, direct-execution
denial, device scope, tenant scope, and gateway failure mapping.

## Run

```bash
./language/cpp/build/bin/praxo-cpp-ai-edge-application \
  --tenant acme --device device-100 \
  --intent "Investigate the edge gateway telemetry and draft a review-only remediation."
```

Direct remediation:

```bash
./language/cpp/build/bin/praxo-cpp-ai-edge-application \
  --device device-100 --intent "Remediate now for device-100."
```

Expected: exit code 2 with `AGENT_POLICY_DENIED` and zero effects.

Simulated gateway failure:

```bash
./language/cpp/build/bin/praxo-cpp-ai-edge-application \
  --device device-100 --simulate-failure
```

Expected: exit code 1 with `TOOL_ERROR` after one read and no draft.

## Boundaries

- No real fieldbus, OPC UA, socket, device SDK, or device write.
- No durable incident store, exactly-once effect, or production identity.
- Fixture device adapter and deterministic model are teaching components.
- Local C++ source build; not registry-package evidence.
- No live-model reasoning evidence is recorded.
