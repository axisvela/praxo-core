# 行为实验矩阵

**状态：** 自动生成的证据矩阵，2026-11-02。该实验不是稳定的公开 API。

本页把[行为实验](behavior-lab.md)的汇总展开为场景×语言矩阵和逐语言报告。数据源是 Behavior Lab JSON 报告；每条命令的 stdout/stderr 保留在报告 artifact 中。

## 汇总

| 指标 | 值 |
| --- | ---: |
| 语言数 | 16 |
| 场景数 | 20 |
| 单元格数 | 320 |
| 通过 | 320 |
| 不支持 | 0 |
| 失败 | 0 |
| 源报告 | `report.json` |
| Run ID | `20261102T074406Z-700663b3` |
| Revision | `b6218e5c0ee7e9469452257540e2168d6495916f` |
| 工作区未提交 | False |
| CI 任务 | [GitHub Actions（上方 revision）](https://github.com/axisvela/praxo-core/actions/runs/41407891314/job/125153985339) |

## 能力层级

本矩阵现在覆盖十六个已接入语言。契约层级与行为层级相互独立；定义见[支持政策](support.md)。

| 层级 | 语言 | 当前状态 |
| --- | --- | --- |
| Agent-capable | Go、Python、TypeScript、Java、Rust、R、CSharp | 以全部二十个场景为目标；当前覆盖因语言而异 |
| Extended | C、PHP、Fortran、COBOL、Ruby、Elixir、Erlang、C++、Lua | 在有明确消费者和维护者时逐场景推进 |
| Optional | 其他已声明实现 | 不在当前行为计划内 |

## 矩阵图例

| 单元格 | 含义 |
| --- | --- |
| `S` | 具名场景测试 |
| `G` | 覆盖多个场景的 Java self-test 组 |
| `N` | 原生测试套件；不是场景隔离断言 |
| `-` | 没有场景或套件覆盖 |

## 场景矩阵

| 场景 | Go | Py | TS | Java | Rust | R | CSharp | C | Ftn | COB | Ruby | Ex | Erl | C++ | PHP | Lua |
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

## 逐语言报告

### Go

- 覆盖类型: 场景级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

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

- 覆盖类型: 场景级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

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

- 覆盖类型: 场景级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

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

- 覆盖类型: 组, 场景级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

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

- 覆盖类型: 场景级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

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

- 覆盖类型: 套件级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

```text
Rscript language/r/tests/run_tests.R
```

### CSharp

- 覆盖类型: 套件级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

```text
dotnet run --project language/csharp/Praxo.Tests
```

### C

- 覆盖类型: 套件级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

```text
ctest --test-dir language/c/build --output-on-failure
```

### Fortran

- 覆盖类型: 套件级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

```text
python language/fortran/run-tests.py
```

### COBOL

- 覆盖类型: 套件级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

```text
python language/cobol/run-tests.py
```

### Ruby

- 覆盖类型: 套件级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

```text
ruby language/ruby/tests/run.rb
```

### Elixir

- 覆盖类型: 套件级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

```text
mix run tests/run_tests.exs
```

### Erlang

- 覆盖类型: 套件级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

```text
python language/erlang/run-tests.py
```

### C++

- 覆盖类型: 套件级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

```text
python scripts/cpp_behavior_suite.py
```

### PHP

- 覆盖类型: 套件级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

```text
php language/php/tests/run.php
```

### Lua

- 覆盖类型: 套件级
- 通过: 20/20
- 不支持: 0
- 已覆盖场景: `final-arguments`, `final-name`, `unchanged-single-auth`, `initial-denial`, `startup-cleanup`, `after-run-continue`, `cleanup-failclosed`, `model-cancel-cleanup`, `tool-cancel-cleanup`, `schema-number-unicode`, `call-limit`, `pii-tool-history`, `checkpoint-content`, `capacity-failclosed`, `parallel-tools`, `run-state-isolation`, `stream-callback-error`, `sse-truncated`, `sse-half-packet`, `hitl-decision`
- 未覆盖场景: 无

命令:

```text
lua language/lua/tests/run.lua
```

## 原始证据

CI job 和 artifact 包含每条命令的退出码、耗时、stdout 和 stderr。本矩阵记录状态和覆盖类型，不复制完整命令输出。
