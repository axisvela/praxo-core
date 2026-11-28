import os
import sys

from .behavior_scenario_builders import *

def scenarios_streaming():
    return (
        Scenario(
            "parallel-tools",
            "Tools start concurrently up to the configured limit and keep result order",
            {
                "go": (go_test("^TestRunInvokesToolsInParallel$"),),
                "python": (
                    python_test(
                        "tests.test_parallel.ParallelToolTest."
                        "test_tools_start_in_parallel_and_keep_call_order"
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "maxParallelTools starts tools concurrently and keeps order",
                        "tests/behavior.test.js",
                    ),
                ),
                "java": (concurrency,),
                "csharp": (csharp,),
                "r": (r,),
                "c": (c,),
                "cpp": (cpp,),
                "ruby": (ruby,),
                "cobol": (cobol,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "lua": (lua,),
                "php": (php,),
                "fortran": (fortran,),
                "rust": (
                    rust_test("parallel_tools_start_together_and_keep_result_order"),
                ),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group", "csharp": "suite", "r": "suite", "c": "suite", "cpp": "suite", "ruby": "suite", "cobol": "suite", "elixir": "suite", "erlang": "suite", "lua": "suite", "php": "suite", "fortran": "suite", "rust": "scenario"},
        ),
        Scenario(
            "run-state-isolation",
            "Call-limit state is isolated across concurrent runs",
            {
                "go": (
                    go_test(
                        "^TestCallLimitMiddlewareSeparatesRuns$",
                        "./pkg/agent/middleware",
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_middleware.MiddlewareTest."
                        "test_call_limit_state_is_isolated_by_run"
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "call limit state is isolated by run",
                        "tests/behavior.test.js",
                    ),
                ),
                "java": (guardrail,),
                "fortran": (fortran,),
                "rust": (rust_test("call_limit_state_is_isolated_by_run"),),
                "csharp": (csharp,),
                "php": (php,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "cpp": (cpp,),
                "ruby": (ruby,),
                "cobol": (cobol,),
                "lua": (lua,),
                "r": (r,),
                "c": (c,),
            },
            {
                "go": "scenario",
                "python": "scenario",
                "typescript": "scenario",
                "java": "group",
                "rust": "scenario",
                "fortran": "suite",
                "csharp": "suite",
                "php": "suite",
                "elixir": "suite",
                "erlang": "suite",
                "cpp": "suite",
                "ruby": "suite",
                "cobol": "suite",
                "lua": "suite",
                "r": "suite",
                "c": "suite",
            },
        ),
        Scenario(
            "stream-callback-error",
            "Stream callback failure aborts the run instead of completing it",
            {
                "go": (go_test("^TestAgentStreamErrorAbortsRun$"),),
                "python": (
                    python_test(
                        "tests.test_openaicompat.StreamingAgentTest."
                        "test_stream_callback_failure_aborts_run"
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "stream callback failure aborts run",
                        "tests/behavior.test.js",
                    ),
                ),
                "java": (stream,),
                "csharp": (csharp,),
                "php": (php,),
                "r": (r,),
                "c": (c,),
                "cpp": (cpp,),
                "ruby": (ruby,),
                "cobol": (cobol,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "lua": (lua,),
                "fortran": (fortran,),
                "rust": (rust_test("stream_callback_failure_aborts_run"),),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "scenario", "csharp": "suite", "php": "suite", "r": "suite", "c": "suite", "cpp": "suite", "ruby": "suite", "cobol": "suite", "elixir": "suite", "erlang": "suite", "lua": "suite", "fortran": "suite", "rust": "scenario"},
        ),
        Scenario(
            "sse-truncated",
            "SSE streams without completion are rejected",
            {
                "go": (
                    go_test(
                        "^TestAdapterGenerateStreamRejectsTruncatedStream$",
                        "./adapters/openaicompat",
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_openaicompat.OpenAICompatTest."
                        "test_generate_stream_rejects_truncated_stream"
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "OpenAI-compatible stream rejects truncation",
                        "tests/openaicompat.test.js",
                    ),
                ),
                "java": (adapter,),
                "csharp": (csharp,),
                "php": (php,),
                "r": (r,),
                "c": (c,),
                "cpp": (cpp,),
                "ruby": (ruby,),
                "cobol": (cobol,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "lua": (lua,),
                "fortran": (fortran,),
                "rust": (rust_test("sse_stream_rejects_truncation_and_half_packets"),),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group", "csharp": "suite", "php": "suite", "r": "suite", "c": "suite", "cpp": "suite", "ruby": "suite", "cobol": "suite", "elixir": "suite", "erlang": "suite", "lua": "suite", "fortran": "suite", "rust": "scenario"},
        ),
        Scenario(
            "sse-half-packet",
            "SSE half-packets fail instead of being silently dropped",
            {
                "go": (
                    go_test(
                        "^TestAdapterGenerateStreamRejectsHalfPacket$",
                        "./adapters/openaicompat",
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_openaicompat.OpenAICompatTest."
                        "test_generate_stream_rejects_half_packet"
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "OpenAI-compatible stream rejects half packet",
                        "tests/openaicompat.test.js",
                    ),
                ),
                "java": (adapter,),
                "csharp": (csharp,),
                "php": (php,),
                "r": (r,),
                "c": (c,),
                "cpp": (cpp,),
                "ruby": (ruby,),
                "cobol": (cobol,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "lua": (lua,),
                "fortran": (fortran,),
                "rust": (rust_test("sse_stream_rejects_truncation_and_half_packets"),),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group", "csharp": "suite", "php": "suite", "r": "suite", "c": "suite", "cpp": "suite", "ruby": "suite", "cobol": "suite", "elixir": "suite", "erlang": "suite", "lua": "suite", "fortran": "suite", "rust": "scenario"},
        ),
        Scenario(
            "hitl-decision",
            "Interrupted calls apply approve, edit, reject, and respond decisions",
            {
                "go": (
                    go_test(
                        "^(TestInterruptEditReplacesArguments|"
                        "TestInterruptRejectFailsRun|"
                        "TestInterruptRespondSkipsTool|"
                        "TestInterruptApproveRunsTool|"
                        "TestInterruptInvalidDecision)$"
                    ),
                ),
                "python": (python_test("tests.test_hitl"),),
                "typescript": (
                    typescript_test(
                        "approve|edit|reject|respond|invalid|unhandled|"
                        "boolean|emits",
                        "tests/hitl.test.js",
                    ),
                ),
                "java": (java_test("AgentHitlSelfTest"),),
                "rust": (rust_hitl_test(),),
                "r": (r_suite(),),
                "csharp": (csharp_suite(),),
                "ruby": (ruby_suite(),),
                "php": (php_suite(),),
                "lua": (lua_suite(),),
                "cpp": (cpp_suite(),),
                "elixir": (elixir_suite(),),
                "erlang": (native_suite("erlang"),),
                "c": (c_suite(),),
                "fortran": (native_suite("fortran"),),
                "cobol": (native_suite("cobol"),),
            },
            {
                "go": "scenario",
                "python": "scenario",
                "typescript": "scenario",
                "java": "group",
                "rust": "scenario",
                "r": "suite",
                "csharp": "suite",
                "ruby": "suite",
                "php": "suite",
                "lua": "suite",
                "cpp": "suite",
                "elixir": "suite",
                "erlang": "suite",
                "c": "suite",
                "fortran": "suite",
                "cobol": "suite",
            },
        ),
    )
