import os
import sys

from .behavior_scenario_builders import *

def scenarios_state():
    return (
        Scenario(
            "model-cancel-cleanup",
            "Cancellation during model work runs after-run and emits failed",
            {
                "go": (go_test("^TestRunCancellationKeepsOriginalErrorOverAfterRunError$"),),
                "python": (
                    python_test(
                        "tests.test_lifecycle.LifecycleTest."
                        "test_cancellation_runs_after_run_and_emits_failed"
                    ),
                ),
                "typescript": (
                    typescript_test("^cancellation runs after-run and emits failed$"),
                ),
                "java": (lifecycle,),
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
                "rust": (rust_test("model_cancellation_runs_after_run_and_emits_failed"),),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group", "csharp": "suite", "php": "suite", "r": "suite", "c": "suite", "cpp": "suite", "ruby": "suite", "cobol": "suite", "elixir": "suite", "erlang": "suite", "lua": "suite", "fortran": "suite", "rust": "scenario"},
        ),
        Scenario(
            "tool-cancel-cleanup",
            "Cancellation during tool work stops effects and runs after-run",
            {
                "go": (go_test("^TestRunStopsStartingToolsAfterCancellation$"),),
                "python": (
                    python_test(
                        "tests.test_lifecycle.LifecycleTest."
                        "test_tool_cancellation_runs_after_run"
                    ),
                ),
                "typescript": (
                    typescript_test("tool cancellation runs after-run"),
                ),
                "java": (lifecycle,),
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
                "rust": (rust_test("tool_cancellation_stops_later_effects_and_runs_after_run"),),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group", "csharp": "suite", "php": "suite", "r": "suite", "c": "suite", "cpp": "suite", "ruby": "suite", "cobol": "suite", "elixir": "suite", "erlang": "suite", "lua": "suite", "fortran": "suite", "rust": "scenario"},
        ),
        Scenario(
            "schema-number-unicode",
            "Schema rejects fractional integers and counts Unicode code points",
            {
                "go": (
                    go_test(
                        "^(TestIntegerRejectsFractions|TestLengthCountsRunes)$",
                        "./pkg/tool/jsonschema",
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_jsonschema.JsonSchemaTest."
                        "test_integer_rejects_fractions",
                        "tests.test_jsonschema.JsonSchemaTest."
                        "test_length_counts_unicode_code_points",
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "schema integer rejects fractions|"
                        "schema length counts Unicode",
                        "tests/behavior.test.js",
                    ),
                ),
                "java": (schema,),
                "fortran": (fortran,),
                "rust": (
                    rust_test(
                        "schema_counts_unicode_and_rejects_fractional_integers"
                    ),
                ),
                "cpp": (cpp,),
                "php": (php,),
                "csharp": (csharp,),
                "lua": (lua,),
                "ruby": (ruby,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "cobol": (cobol,),
                "r": (r,),
                "c": (c,),
            },
            {
                "go": "scenario",
                "python": "scenario",
                "typescript": "scenario",
                "java": "scenario",
                "rust": "scenario",
                "fortran": "suite",
                "cpp": "suite",
                "php": "suite",
                "csharp": "suite",
                "lua": "suite",
                "ruby": "suite",
                "elixir": "suite",
                "erlang": "suite",
                "cobol": "suite",
                "r": "suite",
                "c": "suite",
            },
        ),
        Scenario(
            "call-limit",
            "Model and tool call limits fail closed",
            {
                "go": (
                    go_test(
                        "^(TestCallLimitMiddlewareModelLimit|"
                        "TestCallLimitMiddlewareToolLimit)$",
                        "./pkg/agent/middleware",
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_middleware.MiddlewareTest."
                        "test_model_call_limit",
                        "tests.test_middleware.MiddlewareTest."
                        "test_tool_call_limit",
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "model call limit fails closed|tool call limit fails closed",
                        "tests/behavior.test.js",
                    ),
                ),
                "java": (guardrail,),
                "rust": (rust_test("call_limit_model_and_tool_fail_closed"),),
                "fortran": (fortran,),
                "cobol": (cobol,),
                "ruby": (ruby,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "cpp": (cpp,),
                "php": (php,),
                "csharp": (csharp,),
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
                "cobol": "suite",
                "ruby": "suite",
                "elixir": "suite",
                "erlang": "suite",
                "cpp": "suite",
                "php": "suite",
                "csharp": "suite",
                "lua": "suite",
                "r": "suite",
                "c": "suite",
            },
        ),
        Scenario(
            "pii-tool-history",
            "PII middleware redacts nested tool-call history without mutating input",
            {
                "go": (
                    go_test(
                        "^TestPIIMiddlewareRedactsToolCallHistory$",
                        "./pkg/agent/middleware",
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_middleware.MiddlewareTest."
                        "test_pii_redacts_tool_call_history"
                    ),
                ),
                "typescript": (
                    typescript_test("PII middleware redacts tool-call history"),
                ),
                "java": (pii,),
                "rust": (rust_test("pii_redacts_tool_call_history"),),
                "fortran": (fortran,),
                "cobol": (cobol,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "cpp": (cpp,),
                "php": (php,),
                "csharp": (csharp,),
                "lua": (lua,),
                "ruby": (ruby,),
                "r": (r,),
                "c": (c,),
            },
            {
                "go": "scenario",
                "python": "scenario",
                "typescript": "scenario",
                "java": "scenario",
                "rust": "scenario",
                "fortran": "suite",
                "cobol": "suite",
                "elixir": "suite",
                "erlang": "suite",
                "cpp": "suite",
                "php": "suite",
                "csharp": "suite",
                "lua": "suite",
                "ruby": "suite",
                "r": "suite",
                "c": "suite",
            },
        ),
        Scenario(
            "checkpoint-content",
            "Checkpoint allowlist round-trips nested payload content",
            {
                "go": (
                    go_test("^TestAllowlistRoundTrip$", "./pkg/checkpoint"),
                ),
                "python": (
                    python_test(
                        "tests.test_checkpoint.CheckpointTest."
                        "test_allowlist_round_trips_content"
                    ),
                ),
                "typescript": (
                    typescript_test("checkpoint allowlist round-trips"),
                ),
                "java": (checkpoint,),
                "rust": (rust_test("checkpoint_round_trips"),),
                "fortran": (fortran,),
                "cobol": (cobol,),
                "ruby": (ruby,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "cpp": (cpp,),
                "php": (php,),
                "csharp": (csharp,),
                "lua": (lua,),
                "r": (r,),
                "c": (c,),
            },
            {
                "go": "scenario",
                "python": "scenario",
                "typescript": "scenario",
                "java": "scenario",
                "rust": "scenario",
                "fortran": "suite",
                "cobol": "suite",
                "ruby": "suite",
                "elixir": "suite",
                "erlang": "suite",
                "cpp": "suite",
                "php": "suite",
                "csharp": "suite",
                "lua": "suite",
                "r": "suite",
                "c": "suite",
            },
        ),
        Scenario(
            "capacity-failclosed",
            "Context budget fails closed instead of silently dropping required input",
            {
                "go": (go_test("^TestAgentContextBudgetFailsClosed$"),),
                "python": (
                    python_test(
                        "tests.test_middleware.MiddlewareTest."
                        "test_context_budget_fails_closed"
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "context budget fails closed",
                        "tests/behavior.test.js",
                    ),
                ),
                "java": (guardrail,),
                "rust": (rust_test("context_budget_fails_closed"),),
                "fortran": (fortran,),
                "cobol": (cobol,),
                "cpp": (cpp,),
                "php": (php,),
                "csharp": (csharp,),
                "lua": (lua,),
                "ruby": (ruby,),
                "elixir": (elixir,),
                "erlang": (erlang,),
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
                "cobol": "suite",
                "cpp": "suite",
                "php": "suite",
                "csharp": "suite",
                "lua": "suite",
                "ruby": "suite",
                "elixir": "suite",
                "erlang": "suite",
                "r": "suite",
                "c": "suite",
            },
        ),
    )
