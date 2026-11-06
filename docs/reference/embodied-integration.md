# Embodied Integration Profile

**Status: proposed design, 2026-11-06; consumer pilot not started.** No embodied
runtime, middleware adapter, new Core API or safety guarantee is introduced.
This page specializes the [execution levels](execution-profiles.md) and
[Governed Execution Profile](governed-execution.md), not the normative wire spec.

## Prerequisites

A pilot needs one named consumer, one middleware, one bounded simulation task,
an execution authority, an observation source and a verification rule. None is
selected by this design. Do not build parallel ROS 2, Dora and Zenoh adapters
without consumer evidence. AxisVela products are not required.

The consumer must identify the components enforcing the governed requirements.
An embodied integration cannot skip authorization or weaken failure handling by
selecting an "experimental" label. Development fixtures are not safety controls.

## Responsibility Boundary

| Component | Responsibility |
| --- | --- |
| Core | Local Run, configured policy/HITL, tool invocation, events, cancellation and checkpoint contracts |
| Consumer adapter | Translate operations and observations, correlate IDs, enforce input/resource scope, preserve uncertain outcomes |
| Execution authority | Accept/reject commands, own authoritative remote operation state, deduplication and cancellation confirmation |
| Observation/verifier | Supply timestamped observations, evaluate freshness and verify the declared effect independently of a success reply |
| Workflow/coordination service, if used | Durable recovery, task coordination, leases and fencing |
| Deployment safety system | Emergency stops, interlocks, real-time control, hardware limits and approved safe-state behavior |

Keep local Run, coordination Task, durable Process and robot Mission identifiers
and authority separate. Their names are conceptual mappings, not mandatory Core
fields. A Core run completion must not be promoted into a Mission completion.

## Proposed Acceptance

All governed obligations apply. The following add domain-specific requirements;
these labels are documentation references, not wire codes or a new state enum.

| ID | Requirement | Negative or fault acceptance |
| --- | --- | --- |
| E1 | Authorize the final target, action and parameters | Missing identity, mismatched target/scope or approval edits prevent submission |
| E2 | Separate accepted, completed and effect-verified outcomes | An accepted command or successful tool reply alone never proves the physical effect |
| E3 | Bound observation freshness | Missing/stale/out-of-order observations block dependent new actions; include clock assumptions and freshness limits |
| E4 | Confirm remote cancellation | Cancelling a local Run does not report remote stopping; absent confirmation remains unknown/pending |
| E5 | Resolve duplicate and uncertain submissions | Stable operation key binds payload; response loss/reconnect consults authoritative state before retry |
| E6 | Fail closed on required safety dependencies | Loss of required policy, observation or safety service prevents new dependent actions and invokes consumer-defined escalation |
| E7 | Fence recovery and concurrent ownership | A stale worker/lease cannot issue a new effect; checkpoint restore does not recreate execution authority |
| E8 | Retain correlated evidence | Capture command, authority response, observations, cancellation and verifier result without secrets; report evidence failure separately from effect state |

The consumer defines the freshness threshold, clock domain, timeouts, ownership
and cancellation protocol. This design does not invent universal safe defaults.
For an action already executing, "fail closed" does not mean Core can halt the
machine: the deployment safety authority owns controlled stop/escalation and its
confirmation. Never turn dependency loss into a falsely confirmed safe state.

## Evidence and Promotion

Before claiming an experimental implementation, record the named consumer and
middleware, exact Core/adapter/runtime versions, simulation environment and task,
enforcing components, each E1-E8 test/result and unsupported behavior. Test stale
observations, disconnects, lost responses, duplicate submissions, unconfirmed
cancellation, stale ownership and required safety-service failures.

The [long-running operation recipe](../guides/long-running-operations.md) supplies
software-fixture examples of response loss, status recovery, cancellation and
fencing. It does not supply observations, middleware, production leases or an
embodied consumer; its passing tests do not satisfy this profile.

Separate deterministic fixtures, end-to-end simulation, hardware trials and
production observations under the [test taxonomy](../project/test-taxonomy.md).
Simulation is not hardware or production evidence. Publish limitations and
residual risks with each scoped result; no complete profile pass is claimed here.

## Non-goals

Core is not a robotics platform, motion planner, hardware driver, certified
safety controller, distributed workflow engine or real-time runtime. This profile
provides no emergency-stop implementation, external transaction atomicity or
generic exactly-once guarantee. Shared API/wire changes require the ordinary
compatibility/spec/parity process, not a profile-only exception.
