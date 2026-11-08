# Behavior Lab Matrix

**Status:** generated evidence matrix, 2026-11-02. The lab is not a stable public API.

This page expands the summary in [Behavior Lab](behavior-lab.md) into a scenario-by-language matrix and per-language report sections. The source is a Behavior Lab JSON report; the raw per-command stdout/stderr remains in the report artifact.

## Summary

| Metric | Value |
| --- | ---: |
| Languages | 16 |
| Scenarios | 20 |
| Cells | 320 |
| Passed | 320 |
| Unsupported | 0 |
| Failed | 0 |
| Source report | `report.json` |
| Run ID | `20261102T074406Z-700663b3` |
| Revision | `b6218e5c0ee7e9469452257540e2168d6495916f` |
| Working tree dirty | False |
| CI job | [GitHub Actions (revision above)](https://github.com/axisvela/praxo-core/actions/runs/41407891314/job/125153985339) |

## Capability tiers

The matrix now covers sixteen wired languages. Contract tier is separate from behavior tier; see the [support policy](support.md).

| Tier | Languages | Current status |
| --- | --- | --- |
| Agent-capable | Go, Python, TypeScript, Java, Rust, R, CSharp | Targets all twenty scenarios; current coverage varies by language |
| Extended | C, PHP, Fortran, COBOL, Ruby, Elixir, Erlang, C++, Lua | Advances scenario by scenario with a named consumer and maintainer |
| Optional | Other declared implementations | Outside the current behavior program |

## Matrix legend

| Cell | Meaning |
| --- | --- |
| `S` | Named scenario test |
| `G` | Java self-test group covering multiple scenarios |
| `N` | Native test suite; not isolated to the scenario |
| `-` | No scenario or suite coverage |

## Scenario matrix

| Scenario | Go | Py | TS | Java | Rust | R | CSharp | C | Ftn | COB | Ruby | Ex | Erl | C++ | PHP | Lua |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `final-arguments` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `final-name` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `unchanged-single-auth` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `initial-denial` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `startup-cleanup` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `after-run-continue` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `cleanup-failclosed` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `model-cancel-cleanup` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `tool-cancel-cleanup` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `schema-number-unicode` | S | S | S | S | S | N | N | N | N | N | N | N | N | N | N | N |
| `call-limit` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `pii-tool-history` | S | S | S | S | S | N | N | N | N | N | N | N | N | N | N | N |
| `checkpoint-content` | S | S | S | S | S | N | N | N | N | N | N | N | N | N | N | N |
| `capacity-failclosed` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `parallel-tools` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `run-state-isolation` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `stream-callback-error` | S | S | S | S | S | N | N | N | N | N | N | N | N | N | N | N |
| `sse-truncated` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `sse-half-packet` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |
| `hitl-decision` | S | S | S | G | S | N | N | N | N | N | N | N | N | N | N | N |

## Per-language reports

### Go

- Coverage: scenario
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
go test ./pkg/agent ^TestFinalToolArgumentsAuthorized$
go test ./pkg/agent ^(TestFinalToolNameReauthorized|TestFinalToolNameChecksAllowlist)$
go test ./pkg/agent ^TestOriginalToolDenialStillPrecedesMiddleware$
go test ./pkg/agent ^TestRunCleansUpEnteredMiddlewareOnStartFailure$
go test ./pkg/agent ^TestRunCleansUpAfterMiddlewareFailure$
go test ./pkg/agent ^(TestRunCompletionCallbackFailureHasSingleTerminalEvent|TestRunFailurePreservesOriginalError)$
go test ./pkg/agent ^TestRunCancellationKeepsOriginalErrorOverAfterRunError$
go test ./pkg/agent ^TestRunStopsStartingToolsAfterCancellation$
go test ./pkg/tool/jsonschema ^(TestIntegerRejectsFractions|TestLengthCountsRunes)$
go test ./pkg/agent/middleware ^(TestCallLimitMiddlewareModelLimit|TestCallLimitMiddlewareToolLimit)$
go test ./pkg/agent/middleware ^TestPIIMiddlewareRedactsToolCallHistory$
go test ./pkg/checkpoint ^TestAllowlistRoundTrip$
go test ./pkg/agent ^TestAgentContextBudgetFailsClosed$
go test ./pkg/agent ^TestRunInvokesToolsInParallel$
go test ./pkg/agent/middleware ^TestCallLimitMiddlewareSeparatesRuns$
go test ./pkg/agent ^TestAgentStreamErrorAbortsRun$
go test ./adapters/openaicompat ^TestAdapterGenerateStreamRejectsTruncatedStream$
go test ./adapters/openaicompat ^TestAdapterGenerateStreamRejectsHalfPacket$
go test ./pkg/agent ^(TestInterruptEditReplacesArguments|TestInterruptRejectFailsRun|TestInterruptRespondSkipsTool|TestInterruptApproveRunsTool|TestInterruptInvalidDecision)$
```

### Python

- Coverage: scenario
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
python tests.test_authorization.AuthorizationTest.test_middleware_argument_change_is_reauthorized
python tests.test_authorization.AuthorizationTest.test_middleware_name_change_uses_final_tool_and_authorization tests.test_authorization.AuthorizationTest.test_final_name_must_remain_allowed
python tests.test_authorization.AuthorizationTest.test_unchanged_tool_is_authorized_once
python tests.test_authorization.AuthorizationTest.test_initial_denial_prevents_middleware_and_effect
python tests.test_lifecycle.LifecycleTest.test_startup_failure_cleans_entered_and_emits_no_events
python tests.test_lifecycle.LifecycleTest.test_cleanup_continues_and_preserves_run_error
python tests.test_lifecycle.LifecycleTest.test_cleanup_error_after_success_fails_closed
python tests.test_lifecycle.LifecycleTest.test_cancellation_runs_after_run_and_emits_failed
python tests.test_lifecycle.LifecycleTest.test_tool_cancellation_runs_after_run
python tests.test_jsonschema.JsonSchemaTest.test_integer_rejects_fractions tests.test_jsonschema.JsonSchemaTest.test_length_counts_unicode_code_points
python tests.test_middleware.MiddlewareTest.test_model_call_limit tests.test_middleware.MiddlewareTest.test_tool_call_limit
python tests.test_middleware.MiddlewareTest.test_pii_redacts_tool_call_history
python tests.test_checkpoint.CheckpointTest.test_allowlist_round_trips_content
python tests.test_middleware.MiddlewareTest.test_context_budget_fails_closed
python tests.test_parallel.ParallelToolTest.test_tools_start_in_parallel_and_keep_call_order
python tests.test_middleware.MiddlewareTest.test_call_limit_state_is_isolated_by_run
python tests.test_openaicompat.StreamingAgentTest.test_stream_callback_failure_aborts_run
python tests.test_openaicompat.OpenAICompatTest.test_generate_stream_rejects_truncated_stream
python tests.test_openaicompat.OpenAICompatTest.test_generate_stream_rejects_half_packet
python tests.test_hitl
```

### TypeScript

- Coverage: scenario
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
node --test tests/sdk.test.js middleware argument changes
node --test tests/sdk.test.js middleware name changes|final name must remain allowed
node --test tests/sdk.test.js unchanged tool is authorized once
node --test tests/sdk.test.js initial policy denial prevents middleware
node --test tests/sdk.test.js startup failure cleans entered middleware
node --test tests/sdk.test.js cleanup continues and preserves
node --test tests/sdk.test.js cleanup error after success
node --test tests/sdk.test.js ^cancellation runs after-run and emits failed$
node --test tests/sdk.test.js tool cancellation runs after-run
node --test tests/behavior.test.js schema integer rejects fractions|schema length counts Unicode
node --test tests/behavior.test.js model call limit fails closed|tool call limit fails closed
node --test tests/sdk.test.js PII middleware redacts tool-call history
node --test tests/sdk.test.js checkpoint allowlist round-trips
node --test tests/behavior.test.js context budget fails closed
node --test tests/behavior.test.js maxParallelTools starts tools concurrently and keeps order
node --test tests/behavior.test.js call limit state is isolated by run
node --test tests/behavior.test.js stream callback failure aborts run
node --test tests/openaicompat.test.js OpenAI-compatible stream rejects truncation
node --test tests/openaicompat.test.js OpenAI-compatible stream rejects half packet
node --test tests/hitl.test.js approve|edit|reject|respond|invalid|unhandled|boolean|emits
```

### Java

- Coverage: group, scenario
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
java com.axisvela.praxo.agent.AgentAuthorizationSelfTest
java com.axisvela.praxo.agent.AgentLifecycleSelfTest
java com.axisvela.praxo.jsonschema.JsonSchemaSelfTest
java com.axisvela.praxo.agent.AgentGuardrailSelfTest
java com.axisvela.praxo.middleware.PiiMiddlewareSelfTest
java com.axisvela.praxo.checkpoint.CheckpointSelfTest
java com.axisvela.praxo.agent.AgentConcurrencySelfTest
java com.axisvela.praxo.agent.AgentStreamSelfTest
java --add-modules jdk.httpserver com.axisvela.praxo.adapters.OpenAICompatibleSelfTest
java com.axisvela.praxo.agent.AgentHitlSelfTest
```

### Rust

- Coverage: scenario
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
cargo test --test sdk final_arguments_are_reauthorized_and_executed
cargo test --test sdk final_name_uses_final_tool_and_checks_allowlist
cargo test --test sdk unchanged_tool_is_authorized_once
cargo test --test sdk initial_denial_precedes_middleware_and_effect
cargo test --test sdk startup_failure_cleans_entered_without_events
cargo test --test sdk after_run_continues_and_preserves_run_error
cargo test --test sdk cleanup_error_after_success_fails_closed
cargo test --test sdk model_cancellation_runs_after_run_and_emits_failed
cargo test --test sdk tool_cancellation_stops_later_effects_and_runs_after_run
cargo test --test sdk schema_counts_unicode_and_rejects_fractional_integers
cargo test --test sdk call_limit_model_and_tool_fail_closed
cargo test --test sdk pii_redacts_tool_call_history
cargo test --test sdk checkpoint_round_trips
cargo test --test sdk context_budget_fails_closed
cargo test --test sdk parallel_tools_start_together_and_keep_result_order
cargo test --test sdk call_limit_state_is_isolated_by_run
cargo test --test sdk stream_callback_failure_aborts_run
cargo test --test sdk sse_stream_rejects_truncation_and_half_packets
cargo test --test hitl
```

### R

- Coverage: suite
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
Rscript language/r/tests/run_tests.R
```

### CSharp

- Coverage: suite
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
dotnet run --project language/csharp/Praxo.Tests
```

### C

- Coverage: suite
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
ctest --test-dir language/c/build --output-on-failure
```

### Fortran

- Coverage: suite
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
python language/fortran/run-tests.py
```

### COBOL

- Coverage: suite
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
python language/cobol/run-tests.py
```

### Ruby

- Coverage: suite
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
ruby language/ruby/tests/run.rb
```

### Elixir

- Coverage: suite
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
mix run tests/run_tests.exs
```

### Erlang

- Coverage: suite
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
python language/erlang/run-tests.py
```

### C++

- Coverage: suite
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
python scripts/cpp_behavior_suite.py
```

### PHP

- Coverage: suite
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
php language/php/tests/run.php
```

### Lua

- Coverage: suite
- Passed: 20/20
- Unsupported: 0
- Covered scenarios: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- Unsupported scenarios: none

Commands:

```text
lua language/lua/tests/run.lua
```

## Raw evidence

The CI job and artifact contain the per-command exit code, duration, stdout, and stderr. This matrix records status and coverage, not the full command output.
