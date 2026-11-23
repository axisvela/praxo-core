# Examples

Use examples by task first, then by language. Go reference and cross-language
examples live in the repository
[`examples/`](https://github.com/axisvela/praxo-core/tree/main/examples)
directory. Language-specific examples live under
`language/<language>/examples/` so they are included in the dedicated language
mirror repositories. For the thirteen-theme, thirty-one-language matrix, see
[Language Coverage](language-coverage.md).

## Depth and Evidence

New domain application tutorials live in `language/<language>/Tutorial/`, as a
sibling of `examples/`. See the [Tutorial Plan](tutorial-plan.md) for the
scenario map, current status and delivery standard. Start with
[Python order review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/order-review)
or [TypeScript order support](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/order-review).
Both use the local synthetic service in
[agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services); they are
initial deterministic slices, not completed enterprise Web applications.
Existing examples and published documentation URLs remain unchanged.
The teaching backend is public MIT source and runs locally; no hosted business
endpoint is provided. The original demo repository remains private.
The [Java order review tutorial](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/order-review)
adds a loopback HTTP entry point and a JUnit contract fixture. Its local runtime
is blocked by this workstation's JVM launcher; Linux CI compilation and
mock-backed Agent/Web tests passed at `3c2063f9` in
[run 45031868787](https://github.com/axisvela/praxo-core/actions/runs/45031868787).
The private business-service integration job was skipped in that historical run.
The current integration job uses a pinned public backend revision, without
private credentials. All three native CLI clients passed against the real local
teaching backend at `8b0593bb` in
[run 45033109188](https://github.com/axisvela/praxo-core/actions/runs/45033109188),
using published packages and deterministic models, not live providers.

The [C# order service desk](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/order-review)
adds an ASP.NET Core minimal API and native Core CLI. Local self-tests and a
real Web-to-order-service path pass. Four-language CLI and C# Web integration
passed at Core `ae953050`, public backend `cd08b09`, in
[run 45034303513](https://github.com/axisvela/praxo-core/actions/runs/45034303513).
These are deterministic teaching integrations, not production identity or live-model evidence.

The [PowerShell Windows diagnostics tutorial](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics)
is the first operations-shaped path: fixture and local read-only service/disk
checks, with policy denial and dependency failure. It reuses the shared C# Core
through `praxo-core-ps`; it does not execute repairs, remote commands or a live model.
Local Windows PowerShell 7.7.0 tests passed 4/4. Hosted Windows CI also passed
the C# Core build and all four source-mode checks at `5afe6e35` in
[run 45036962205](https://github.com/axisvela/praxo-core/actions/runs/45036962205).

The [Perl log triage tutorial](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage)
adds a native Perl operations path: one fixed fixture log, severity counts and a
structured report, with policy denial and dependency-failure checks. It does not
read arbitrary paths, execute shell commands, send alerts or call a live model.
Local Perl 5.40.3 tests passed, and Linux CI passed at `3b5edcc7` in
[run 45038008192](https://github.com/axisvela/praxo-core/actions/runs/45038008192).

The [R data-quality tutorial](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/data-quality)
adds an analytics path: a fixed data frame, native R statistics and a structured
report that packages tool-computed values. Policy denial and dependency-failure
checks are included. It does not read arbitrary files, run SQL, execute shell,
install packages or call a live model. Local R 4.6.1 tests passed, and Linux CI
passed at `e89c9037` in
[run 45039622807](https://github.com/axisvela/praxo-core/actions/runs/45039622807).

The [COBOL batch exception review tutorial](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review)
reuses the existing deterministic batch handoff fixture. It checks a separate
COBOL review worker, an unavailable worker and a timeout, while requiring the
batch output and exception file to remain unchanged. It does not implement real
posting, payments, durable queues or recovery proof. Local GnuCOBOL 2.0.0 and
Python 3.14 checks passed, and Linux CI passed at `01d9b1ff` in
[run 45040372057](https://github.com/axisvela/praxo-core/actions/runs/45040372057).

The [Julia experiment-comparison tutorial](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/experiment-comparison)
computes baseline/candidate means and delta over fixed results through the native
Julia Core, then packages the computed evidence in a report. It includes policy
denial and dependency-failure checks. It does not read arbitrary data, execute
model-provided Julia code, install packages or call a live model. Local Julia
1.13.2 tests passed, and Linux CI passed at `bbf12c42` in
[run 45041423996](https://github.com/axisvela/praxo-core/actions/runs/45041423996).

The [Octave/MATLAB signal-trends tutorial](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends)
computes fixed-signal mean, peak-to-peak, RMS and threshold anomalies through the
shared MATLAB/Octave Core, then packages the computed evidence in a report. It
includes policy denial and dependency-failure checks. It does not read arbitrary
files, execute model-provided code, control devices or call a live model. Local
GNU Octave 11.3.0 tests passed; native MATLAB is not verified. Linux CI passed
at `0664a194` in
[run 45042266323](https://github.com/axisvela/praxo-core/actions/runs/45042266323).

The [Python office Q&A tutorial](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa)
answers fixed office-policy questions with document citations. A scoped search
tool returns evidence, and the deterministic model packages the top result into
an answer. It includes policy denial and index-failure checks. It does not read
arbitrary files, call connectors, send email or call a live model. Local Python
3.14 checks passed, and Linux CI passed at `cfd850a6` in
[run 45043537084](https://github.com/axisvela/praxo-core/actions/runs/45043537084).

The [TypeScript customer-support tutorial](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support)
streams a cited support reply over SSE using native Core tools for a fixed order
and public shipping policy. It includes missing-credential, policy-denial and
dependency-failure checks. It does not send replies, change orders, issue refunds,
read arbitrary files or call a live model. Local Node 24 checks passed, and Linux
CI passed at `39558592` in
[run 45086046576](https://github.com/axisvela/praxo-core/actions/runs/45086046576).

The [Java wealth review tutorial](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/wealth-service)
adds a review-only finance service over a fixed `acct-100` portfolio. It reads the
portfolio, drafts a rebalance for human review and never places trades or
transfers cash. Policy denies `acct-200`; the Web boundary covers 401 and 503.
Local compilation passed, but the local JVM blocks runtime execution. Linux CI
passed at `827d47ca` in
[run 45088386879](https://github.com/axisvela/praxo-core/actions/runs/45088386879).
No real account, market data or brokerage integration exists.

The [C# sales/CRM tutorial](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/sales-crm)
adds a review-only sales service over a fixed `customer-100` record. It reads the
customer, drafts a follow-up for human review and never writes the CRM or sends
email. Policy denies `customer-200`; the Web boundary covers 401 and 503. Local
.NET 8 build and self-tests passed, and Linux CI passed at `00641594` in
[run 45093076768](https://github.com/axisvela/praxo-core/actions/runs/45093076768).
No real customer, CRM connector or outbound message exists.

The [Lua host-embedding tutorial](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding)
embeds the native Lua Core in a host event loop with two fixed callbacks:
`read_device` and `draft_action`. The host receives a `draft_only`,
`review_required` operator notification. It does not send device commands, open
sockets or call a live model. Local Lua 5.4.6 tests passed, and Linux CI passed at
`9163d03a` in
[run 45095923385](https://github.com/axisvela/praxo-core/actions/runs/45095923385).

The [Rust IoT gateway tutorial](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/iot-gateway)
reads a fixed `device-100` snapshot through an explicit application-owned
`GatewayAdapter` trait and drafts one operator review action. Policy denies
`device-200` before the adapter (`reads=0`), and a simulated adapter failure
fails after one read. The adapter is an in-process fixture; no MQTT, OPC UA,
socket, device command or live model is implemented. Local `cargo` checks passed,
and Linux CI passed at `a78de75e` in
[run 45098362060](https://github.com/axisvela/praxo-core/actions/runs/45098362060).

The [Zig gateway health tutorial](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health)
reads a fixed `gateway-100` health snapshot through an explicit application-owned
`GatewayAdapter` function table and drafts one `restart_telemetry` review action.
Policy denies `gateway-200` before the adapter (`reads=0`), and a simulated
adapter failure fails after one read. The adapter is an in-process fixture; no
MQTT, OPC UA, socket, device command or live model is implemented. Local Zig
0.17.0 checks passed, and Linux CI passed at `0b2f15d6` in
[run 45102354617](https://github.com/axisvela/praxo-core/actions/runs/45102354617).

The catalog uses the depth labels from the
[Language Coverage depth audit](language-coverage.md#depth-audit):

| Depth | What it means |
| --- | --- |
| Mechanism check | Isolated schema, handler, retry, or callback assertions; may not invoke Core |
| Core integration | Invokes the actual Core model, tool, policy, checkpoint, or event seam for the claimed behavior |
| Application tutorial | Documents setup, an input-to-output task, failure handling, and continuation |

A recorded run is separate from depth: it names the revision, toolchain, command,
output, and limits. A source entry is not a working path. Check the depth audit
for mechanism-only themes and the
[verification evidence](../project/verification-evidence.md) for recorded runs.

## Choose by Task

| Task | Example | Notes |
| --- | --- | --- |
| Run a real model | [Live Model Golden Path](live-model-golden-path.md) | Published package, OpenAI-compatible endpoint, one `get_time(zone)` tool |
| Connect another provider or MCP | [Provider and MCP walkthrough](../guides/provider-walkthrough.md), [MCP tutorial](../guides/mcp-tutorial.md) | Published-package adapters, local MCP clients, and transport boundaries |
| Host MCP tools | [`language/python/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/mcp), [`language/typescript/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/mcp), [`language/csharp/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/mcp), [`language/rust/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/mcp), [`language/java/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/mcp), [`language/ruby/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/mcp), [`language/php/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/mcp), [`language/elixir/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/mcp), [`language/erlang/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/mcp), [`language/lua/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/mcp), [`language/r/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/mcp), [`language/c/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/mcp), [`language/cpp/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/mcp), [`language/fortran/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/mcp), [`language/cobol/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/mcp) | In-process or stdio MCP clients with deterministic tool discovery and calls |
| Add provider fallback | [`language/python/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/provider-fallback), [`language/typescript/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/provider-fallback), [`language/csharp/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/provider-fallback), [`language/rust/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/provider-fallback), [`language/ruby/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/provider-fallback), [`language/php/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/provider-fallback), [`language/c/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/provider-fallback), [`language/cpp/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/provider-fallback), [`language/fortran/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/provider-fallback), [`language/elixir/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/provider-fallback), [`language/erlang/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/provider-fallback), [`language/lua/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/provider-fallback), [`language/r/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/provider-fallback), [`language/cobol/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/provider-fallback), [`language/java/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/provider-fallback) | Primary model failure falls back to a second model; deterministic tests |
| Retry transient model failures | [`language/python/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/retry), [`language/typescript/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/retry), [`language/csharp/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/retry), [`language/rust/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/retry), [`language/java/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/retry), [`language/ruby/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/retry), [`language/php/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/retry), [`language/c/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/retry), [`language/cpp/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/retry), [`language/fortran/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/retry), [`language/elixir/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/retry), [`language/erlang/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/retry), [`language/lua/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/retry), [`language/r/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/retry), [`language/cobol/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/retry) | Bounded model middleware retries only retryable errors and preserves exhausted failures |
| Observe agent events | [`language/python/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/event-sink), [`language/typescript/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/event-sink), [`language/csharp/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/event-sink), [`language/rust/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/event-sink), [`language/java/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/event-sink), [`language/ruby/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/event-sink), [`language/php/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/event-sink), [`language/c/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/event-sink), [`language/cpp/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/event-sink), [`language/fortran/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/event-sink), [`language/elixir/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/event-sink), [`language/erlang/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/event-sink), [`language/lua/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/event-sink), [`language/r/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/event-sink), [`language/cobol/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/event-sink) | `run.started`, `tool.call`, `run.completed`, and `FilterSink` with deterministic tests |
| Stream a response | [`language/python/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/streaming), [`language/typescript/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/streaming), [`language/csharp/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/streaming), [`language/rust/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/streaming), [`language/ruby/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/streaming), [`language/php/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/streaming), [`language/c/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/streaming), [`language/cpp/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/streaming), [`language/fortran/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/streaming), [`language/elixir/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/streaming), [`language/erlang/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/streaming), [`language/lua/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/streaming), [`language/r/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/streaming), [`language/cobol/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/streaming), [`language/java/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/streaming) | Delta callbacks reconstruct the final output; deterministic fake streaming models |
| Verify installation and denial | [Consumer starters](index.md) | Published package plus deterministic allow/deny checks |
| Produce validated JSON | [Structured Output tutorial](../guides/structured-output-tutorial.md) | Thirty-one language examples with deterministic schema accept/reject checks; published-package paths for Python, TypeScript, Java, C#, and Rust |
| Process a batch into validated JSON with failure and resume | [Python Structured Output Application](../guides/python-structured-output-app.md) | Application-shaped Python path with input, result, and error files; fixture and live modes |
| Validate structured output | [Language Coverage](language-coverage.md), [Structured Output tutorial](../guides/structured-output-tutorial.md) | All 31 declared languages under `language/<language>/examples/structured-output`; valid output accepted and invalid output rejected |
| Build a workspace agent | [Workspace Agent tutorial](../guides/workspace-agent-tutorial.md) | Read-only published-package Go application |
| Diagnose a Windows service and disk read-only | [PowerShell Windows diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics) | Fixed read-only tools over the shared C# Core; no repairs, remote hosts, or arbitrary shell commands |
| Triage a synthetic log and produce a report | [Perl log triage](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage) | Native Perl Core, fixed fixture log, severity counts, denial and dependency-failure checks |
| Assess dataset quality with computed evidence | [R data quality](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/data-quality) | Native R statistics over a fixed data frame; the model packages tool-computed values, not invented numbers |
| Review a bank batch exception handoff | [COBOL batch exception review](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review) | Reuses the deterministic COBOL batch fixture; separate review worker, unavailable and timeout paths; no real posting |
| Compare fixed experiment results | [Julia experiment comparison](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/experiment-comparison) | Native Julia means/delta over fixed results; model packages computed evidence, no arbitrary code or causal claim |
| Review signal trends and threshold anomalies | [Octave/MATLAB signal trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends) | Native Signal metrics over a fixed signal; Octave run verified, native MATLAB not claimed; no device control |
| Answer office policy questions with citations | [Python office Q&A](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa) | Native Core, fixed document fixtures, citation-bearing answer, scoped denial and index failure |
| Stream a support reply with citations | [TypeScript customer support](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support) | Native Core, fixed order/policy tools, SSE deltas, auth/denial and dependency failure |
| Draft a wealth rebalance for human review | [Java wealth review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/wealth-service) | Native Core, fixed portfolio, draft-only allocation, policy denial and service boundary; no trades or transfers |
| Draft a sales follow-up for human review | [C# sales/CRM](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/sales-crm) | Native Core, fixed customer, draft-only follow-up, policy denial and Web boundary; no CRM write or email send |
| Embed the Agent in a Lua host device loop | [Lua host embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding) | Native Lua Core, host callbacks, read-only device state, draft-only operator action; no device command or socket |
| Diagnose an edge gateway read-only | [Rust IoT gateway](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/iot-gateway) | Native Rust Core, explicit `GatewayAdapter` fixture, fixed telemetry, draft-only operator action; no MQTT, OPC UA, socket or device write |
| Check small gateway health read-only | [Zig gateway health](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health) | Native Zig Core, explicit `GatewayAdapter` function table, fixed health, draft-only operator action; no MQTT, OPC UA, socket or device write |
| Embed in an application | [Application Integration Checklist](../guides/application-integration-checklist.md) | Risk-tiered checklist for read-only, side-effecting, and high-risk deployments |
| Run Core behind HTTP | [Embedded HTTP service tutorial](../guides/embedded-service-tutorial.md), [Language Coverage](language-coverage.md) | Executable HTTP servers for Go, Python, TypeScript, Java, C#, and Rust; transport-neutral handler examples for every other declared language |
| Explore the Go reference | [`examples/reference`](https://github.com/axisvela/praxo-core/tree/main/examples/reference) | Go reference application |
| Add policy and approvals | [`examples/governed-workspace`](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace) | Go example of governed execution boundaries |
| Enforce identity and policy | [Identity and policy](../guides/identity-policy.md), [Language Coverage](language-coverage.md) | Trusted principal binding, model-claim rejection, and pre-effect denial for all 31 declared languages |
| Add checkpoints | [`examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/examples/checkpoint) | Go checkpoint-store example |
| Persist checkpoints | [`language/python/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/checkpoint), [`language/typescript/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/checkpoint), [`language/csharp/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/checkpoint), [`language/rust/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/checkpoint), [`language/java/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/checkpoint), [`language/ruby/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/checkpoint), [`language/php/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/checkpoint), [`language/c/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/checkpoint), [`language/cpp/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/checkpoint), [`language/fortran/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/checkpoint), [`language/elixir/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/checkpoint), [`language/erlang/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/checkpoint), [`language/lua/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/checkpoint), [`language/r/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/checkpoint), [`language/cobol/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/checkpoint) | Application-owned storage with allowlisted payloads; latest-record round trip and unregistered-type rejection |
| Add a plugin | [`examples/plugin`](https://github.com/axisvela/praxo-core/tree/main/examples/plugin) | Go process/WASM plugin host example |
| Delegate work | [`examples/multiagent`](https://github.com/axisvela/praxo-core/tree/main/examples/multiagent) | Go local delegation example |
| Run a representative chain | [`examples/representative-chain`](https://github.com/axisvela/praxo-core/tree/main/examples/representative-chain), Python [`language/python/examples/representative-chain`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/representative-chain), TypeScript [`language/typescript/examples/representative-chain`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/representative-chain) | Go real-model chain plus deterministic Python/TypeScript counterparts covering MCP, final authorization, delegation, OTel/Harmovela, and denial zero effect |
| Use focused recipes | [`examples/recipes`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes) | Go recipes for providers, events, retries, VFS, and related seams |
| Integrate an ecosystem component | [`examples/ecosystem`](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem) | Optional AxisVela adapter shapes |

## Prototype Paths

Pick one path and finish it before adding another integration. These groups are
guidance, not release gates.

| Group | Outcome | Start with |
| --- | --- | --- |
| Basic | Install a published package, call a tool, and deny one unsafe call | [Quickstart](quickstart.md), [Live Model Golden Path](live-model-golden-path.md), [Consumer starters](index.md) |
| Integration | Add one real boundary: MCP, provider fallback, structured output, streaming, or HTTP service | [Provider and MCP walkthrough](../guides/provider-walkthrough.md), [Structured Output tutorial](../guides/structured-output-tutorial.md), [Embedded HTTP service tutorial](../guides/embedded-service-tutorial.md) |
| Hardening | Make one integration safe to deny, approve, persist, retry, or cancel | [Identity and policy](../guides/identity-policy.md), [Application Integration Checklist](../guides/application-integration-checklist.md), [Consumer test template](../guides/consumer-test-template.md) |
| Advanced | Add plugins, delegation, long-running operations, workspace providers, or embodied seams | [Advanced examples](../guides/advanced-examples.md), [Plugin guide](../guides/plugins.md), [Multi-agent patterns](../guides/multi-agent.md), [Long-running operations](../guides/long-running-operations.md) |

Depth varies inside every group. Basic examples are Core integrations with
deterministic checks; Integration examples mix Core integrations and mechanism
checks; Hardening and Advanced examples are application-shaped Go recipes or
tutorials unless a language README says otherwise. Use the
[depth audit](language-coverage.md#depth-audit) rather than assuming equal depth
from the task label.

The primary SDKs share the same task-oriented catalog, but each language keeps
its own install command and executable example. A Go example is not evidence
that another SDK's example runs.

## Examples vs Recipes

- [`examples/recipes`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes)
  contains Go-focused copy-paste recipes and scoped test evidence.
- `examples/` contains runnable projects, including published-package and
  language-specific integrations.

Topics such as structured output, checkpoint stores, identity, VFS containment,
and long-running operations appear in both forms. Use the recipe for the
mechanism and the example for an application-shaped integration; do not copy
both into one project.

## By Language

| Language | Examples |
| --- | --- |
| Go | [`examples/`](https://github.com/axisvela/praxo-core/tree/main/examples) |
| Python | [`language/python/examples`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples) |
| TypeScript | [`language/typescript/examples`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples) |
| Java | [`language/java/examples`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples) |
| C# | [`language/csharp/examples`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples) |
| Rust | [`language/rust/examples`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples) |
| Ruby | [`language/ruby/examples`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples) |
| PHP | [`language/php/examples`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples) |
| C | [`language/c/examples`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples) |
| C++ | [`language/cpp/examples`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples) |
| Fortran | [`language/fortran/examples`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples) |
| Erlang | [`language/erlang/examples`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples) |
| R | [`language/r/examples`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples) |
| COBOL | [`language/cobol/examples`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples) |
| Elixir | [`language/elixir/examples`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples) |
| Lua | [`language/lua/examples`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples) |

Each language example directory has its own README with installation and run
commands. Every declared language includes `consumer`, `live-model`, `hitl`,
and `session-checkpoint` entries. See [Language Coverage](language-coverage.md)
for the per-language matrix. Python, TypeScript, Java, Rust, C#, and other Core
implementations remain independently versioned; use the
[language matrix](../languages/matrix.md) for current support. The only complete
end-to-end prototype tutorial today is the Go [Workspace Agent
tutorial](../guides/workspace-agent-tutorial.md); the other primary SDKs have
task-focused examples but still need a comparable tutorial.

## How Examples Are Organized

- `examples/` contains Go reference examples and cross-language integrations.
- `language/<language>/examples/` contains language-specific runnable examples.
- Language examples are copied into the corresponding discovery mirror.
- Examples that install a published package do not require a repository checkout
  or local package replacement.

Do not treat examples as production security profiles. Identity, durable
approvals, effect reconciliation, and isolation remain application
responsibilities.
