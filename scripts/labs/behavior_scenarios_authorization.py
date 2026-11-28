import os
import sys

from .behavior_scenario_builders import *

def scenarios_authorization():
    return (
        Scenario(
            "final-arguments",
            "Middleware-mutated arguments are reauthorized before effects",
            {
                "go": (go_test("^TestFinalToolArgumentsAuthorized$"),),
                "python": (
                    python_test(
                        "tests.test_authorization.AuthorizationTest."
                        "test_middleware_argument_change_is_reauthorized"
                    ),
                ),
                "typescript": (
                    typescript_test("middleware argument changes"),
                ),
                "java": (auth,),
                "csharp": (csharp,),
                "php": (php,),
                "r": (r,),
                "c": (c,),
                "ruby": (ruby,),
                "cpp": (cpp,),
                "lua": (lua,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "fortran": (fortran,),
                "cobol": (cobol,),
                "rust": (
                    rust_test("final_arguments_are_reauthorized_and_executed"),
                ),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group", "csharp": "suite", "php": "suite", "r": "suite", "c": "suite", "ruby": "suite", "cpp": "suite", "lua": "suite", "elixir": "suite", "erlang": "suite", "fortran": "suite", "cobol": "suite", "rust": "scenario"},
        ),
        Scenario(
            "final-name",
            "Final tool name is checked against allowlist and policy",
            {
                "go": (
                    go_test(
                        "^(TestFinalToolNameReauthorized|TestFinalToolNameChecksAllowlist)$"
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_authorization.AuthorizationTest."
                        "test_middleware_name_change_uses_final_tool_and_authorization",
                        "tests.test_authorization.AuthorizationTest."
                        "test_final_name_must_remain_allowed",
                    ),
                ),
                "typescript": (
                    typescript_test(
                        "middleware name changes|final name must remain allowed"
                    ),
                ),
                "java": (auth,),
                "csharp": (csharp,),
                "php": (php,),
                "r": (r,),
                "c": (c,),
                "ruby": (ruby,),
                "cpp": (cpp,),
                "lua": (lua,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "fortran": (fortran,),
                "cobol": (cobol,),
                "rust": (
                    rust_test("final_name_uses_final_tool_and_checks_allowlist"),
                ),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group", "csharp": "suite", "php": "suite", "r": "suite", "c": "suite", "ruby": "suite", "cpp": "suite", "lua": "suite", "elixir": "suite", "erlang": "suite", "fortran": "suite", "cobol": "suite", "rust": "scenario"},
        ),
        Scenario(
            "unchanged-single-auth",
            "Unchanged tool calls keep one authorization",
            {
                "go": (go_test("^TestFinalToolArgumentsAuthorized$"),),
                "python": (
                    python_test(
                        "tests.test_authorization.AuthorizationTest."
                        "test_unchanged_tool_is_authorized_once"
                    ),
                ),
                "typescript": (
                    typescript_test("unchanged tool is authorized once"),
                ),
                "java": (auth,),
                "csharp": (csharp,),
                "php": (php,),
                "r": (r,),
                "c": (c,),
                "ruby": (ruby,),
                "cpp": (cpp,),
                "lua": (lua,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "fortran": (fortran,),
                "cobol": (cobol,),
                "rust": (rust_test("unchanged_tool_is_authorized_once"),),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group", "csharp": "suite", "php": "suite", "r": "suite", "c": "suite", "ruby": "suite", "cpp": "suite", "lua": "suite", "elixir": "suite", "erlang": "suite", "fortran": "suite", "cobol": "suite", "rust": "scenario"},
        ),
        Scenario(
            "initial-denial",
            "Initial policy denial prevents middleware and effects",
            {
                "go": (go_test("^TestOriginalToolDenialStillPrecedesMiddleware$"),),
                "python": (
                    python_test(
                        "tests.test_authorization.AuthorizationTest."
                        "test_initial_denial_prevents_middleware_and_effect"
                    ),
                ),
                "typescript": (
                    typescript_test("initial policy denial prevents middleware"),
                ),
                "java": (auth,),
                "csharp": (csharp,),
                "php": (php,),
                "r": (r,),
                "c": (c,),
                "ruby": (ruby,),
                "cpp": (cpp,),
                "lua": (lua,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "fortran": (fortran,),
                "cobol": (cobol,),
                "rust": (rust_test("initial_denial_precedes_middleware_and_effect"),),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group", "csharp": "suite", "php": "suite", "r": "suite", "c": "suite", "ruby": "suite", "cpp": "suite", "lua": "suite", "elixir": "suite", "erlang": "suite", "fortran": "suite", "cobol": "suite", "rust": "scenario"},
        ),
        Scenario(
            "startup-cleanup",
            "Before-run failure cleans entered middleware without run events",
            {
                "go": (go_test("^TestRunCleansUpEnteredMiddlewareOnStartFailure$"),),
                "python": (
                    python_test(
                        "tests.test_lifecycle.LifecycleTest."
                        "test_startup_failure_cleans_entered_and_emits_no_events"
                    ),
                ),
                "typescript": (
                    typescript_test("startup failure cleans entered middleware"),
                ),
                "java": (lifecycle,),
                "csharp": (csharp,),
                "php": (php,),
                "r": (r,),
                "c": (c,),
                "ruby": (ruby,),
                "cpp": (cpp,),
                "lua": (lua,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "fortran": (fortran,),
                "cobol": (cobol,),
                "rust": (rust_test("startup_failure_cleans_entered_without_events"),),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group", "csharp": "suite", "php": "suite", "r": "suite", "c": "suite", "ruby": "suite", "cpp": "suite", "lua": "suite", "elixir": "suite", "erlang": "suite", "fortran": "suite", "cobol": "suite", "rust": "scenario"},
        ),
        Scenario(
            "after-run-continue",
            "After-run continues later callbacks and preserves run error",
            {
                "go": (go_test("^TestRunCleansUpAfterMiddlewareFailure$"),),
                "python": (
                    python_test(
                        "tests.test_lifecycle.LifecycleTest."
                        "test_cleanup_continues_and_preserves_run_error"
                    ),
                ),
                "typescript": (
                    typescript_test("cleanup continues and preserves"),
                ),
                "java": (lifecycle,),
                "csharp": (csharp,),
                "php": (php,),
                "r": (r,),
                "c": (c,),
                "ruby": (ruby,),
                "cpp": (cpp,),
                "lua": (lua,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "fortran": (fortran,),
                "cobol": (cobol,),
                "rust": (rust_test("after_run_continues_and_preserves_run_error"),),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group", "csharp": "suite", "php": "suite", "r": "suite", "c": "suite", "ruby": "suite", "cpp": "suite", "lua": "suite", "elixir": "suite", "erlang": "suite", "fortran": "suite", "cobol": "suite", "rust": "scenario"},
        ),
        Scenario(
            "cleanup-failclosed",
            "Cleanup failure fails a successful run closed",
            {
                "go": (
                    go_test(
                        "^(TestRunCompletionCallbackFailureHasSingleTerminalEvent|"
                        "TestRunFailurePreservesOriginalError)$"
                    ),
                ),
                "python": (
                    python_test(
                        "tests.test_lifecycle.LifecycleTest."
                        "test_cleanup_error_after_success_fails_closed"
                    ),
                ),
                "typescript": (
                    typescript_test("cleanup error after success"),
                ),
                "java": (lifecycle,),
                "csharp": (csharp,),
                "php": (php,),
                "r": (r,),
                "c": (c,),
                "ruby": (ruby,),
                "cpp": (cpp,),
                "lua": (lua,),
                "elixir": (elixir,),
                "erlang": (erlang,),
                "fortran": (fortran,),
                "cobol": (cobol,),
                "rust": (rust_test("cleanup_error_after_success_fails_closed"),),
            },
            {"go": "scenario", "python": "scenario", "typescript": "scenario", "java": "group", "csharp": "suite", "php": "suite", "r": "suite", "c": "suite", "ruby": "suite", "cpp": "suite", "lua": "suite", "elixir": "suite", "erlang": "suite", "fortran": "suite", "cobol": "suite", "rust": "scenario"},
        ),
    )
