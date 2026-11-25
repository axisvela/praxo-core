# C++ AI Industrial Edge Agent (AI-native reference source)

A C++ edge integration where the agent drives the primary device-diagnosis
workflow: an operator submits an incident intent, the agent reads
application-owned device telemetry through a `GatewayAdapter`, diagnoses the
condition, and drafts a review-only maintenance action. The agent never writes to
the device.

This repository builds the application as a **static library**. It does not
generate or commit an executable because the local SEP policy blocks executable
artifacts. A downstream host links the library and supplies its own executable
outside this repository.

## Why this language and runtime?

- **Selection basis:** C++ is common in industrial gateways, embedded hosts, and
  performance-sensitive applications that already own a device SDK or fieldbus
  adapter.
- **Demonstrated fit:** A native C++ source target, an application-owned adapter,
  governed tools, policy, and trace code exercise the Core seam without a second
  runtime.
- **Choose when:** Adding a bounded diagnosis/review action to an existing C++
  device or industrial host that already owns process creation and deployment.
- **Do not choose when:** Direct device-SDK code or a simple deterministic runbook
  already solves the task, or when another host provides the same boundary with
  less integration effort.
- **Evidence limit:** Fixture adapter and deterministic model source. The live
  transport source is present, but no executable is generated here, so no local
  runtime or live-model run is recorded.

## AI-native workflow

1. The host passes a tenant, device id, and incident intent to the linked source.
2. The agent reads telemetry through `GatewayAdapter`.
3. The model writes a diagnosis and rationale and drafts a review-only action.
4. The report returns `executions=0`.
5. An operator approves and performs any device action outside the agent.

If the model is removed, the primary gateway workflow disappears.

## Where is the LLM reasoning?

The deterministic path uses a scripted model. It verifies the harness, policy,
failure paths, and trace shape when a host runs it, not LLM reasoning.

The source includes an application-owned `curl` transport for the Core
`OpenAICompatible` adapter. On Windows it adds `--ssl-no-revoke`. Because this
repository cannot generate an executable, that live path is source-only here; no
C++ live-model run is recorded.

## Host integration

| Boundary | Where |
| --- | --- |
| Application source | `application/main.cpp` (`praxo_ai_edge_run`) |
| Device adapter | `GatewayAdapter`, `FixtureGateway` |
| Tools and policy | `application/main.cpp` |
| Trace | `TracingModel` |
| Live transport source | `curl_transport`, `live_model` |
| Build artifact | `libpraxo-cpp-ai-edge-application.a` |

Identity, device transport, approvals, executable creation, and effect
reconciliation remain host-owned.

## Tools and policy

| Tool | Effect | Policy |
| --- | --- | --- |
| `read_device` | Read-only telemetry | Device must be `device-100` |
| `draft_maintenance` | Saves a model-written review-only remediation | `review_remediation` plus diagnosis/rationale |
| `execute_remediation` | Would execute remediation | Always denied in the agent path |

A `Remediate now` or `Execute remediation` intent is denied before telemetry read,
drafting, or execution.

## Build

The target uses the local C++ Core source; it is not a package-registry install.
It produces a static library and no executable:

```bash
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build --target praxo-cpp-ai-edge-application
```

Expected artifact:

```text
libpraxo-cpp-ai-edge-application.a
```

No `--test`, `--live`, or run command is available in this repository because
those would require generating an executable. A host outside this repository can
link the library and provide the executable, test entry, and live command.

## Boundaries

- No executable is generated or committed; SEP blocks local executable artifacts.
- No local runtime test, live-model run, or command-line output is recorded here.
- No real fieldbus, OPC UA, socket, device SDK, or device write.
- No durable incident store, exactly-once effect, or production identity.
- Fixture adapter and deterministic model are teaching components.
- Local C++ source/static-library build; not registry-package evidence.
