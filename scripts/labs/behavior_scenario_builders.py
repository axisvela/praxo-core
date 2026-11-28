from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from pathlib import Path

from scripts.labs.compatibility_lab import Command

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "praxo-behavior-lab-1"

@dataclass(frozen=True)
class Scenario:
    key: str
    title: str
    commands: dict[str, tuple[Command, ...]]
    coverage: dict[str, str]


def go_test(pattern: str, package: str = "./pkg/agent") -> Command:
    return Command(
        "go test " + package + " " + pattern,
        ("go", "test", package, "-run", pattern, "-count=1"),
        ROOT,
    )


def python_test(*names: str) -> Command:
    return Command(
        "python " + " ".join(names),
        (sys.executable, "-m", "unittest", *names),
        ROOT / "language" / "python",
    )


def typescript_test(
    pattern: str,
    file: str = "tests/sdk.test.js",
) -> Command:
    return Command(
        "node --test " + file + " " + pattern,
        ("node", "--test", "--test-name-pattern", pattern, file),
        ROOT / "language" / "typescript",
    )


def java_class_test(qualified_name: str, *options: str) -> Command:
    classpath = "target/classes" + os.pathsep + "target/test-classes"
    return Command(
        "java " + " ".join((*options, qualified_name)),
        ("java", *options, "-cp", classpath, qualified_name),
        ROOT / "language" / "java",
    )


def java_test(name: str) -> Command:
    return java_class_test("com.axisvela.praxo.agent." + name)


def rust_test(name: str) -> Command:
    return Command(
        "cargo test --test sdk " + name,
        ("cargo", "test", "--test", "sdk", name, "--", "--exact"),
        ROOT / "language" / "rust",
    )


def rust_hitl_test() -> Command:
    return Command(
        "cargo test --test hitl",
        ("cargo", "test", "--test", "hitl"),
        ROOT / "language" / "rust",
    )


def native_suite(language: str) -> Command:
    return Command(
        "python language/" + language + "/run-tests.py",
        (sys.executable, "language/" + language + "/run-tests.py"),
        ROOT,
    )


def ruby_suite() -> Command:
    return Command(
        "ruby language/ruby/tests/run.rb",
        ("ruby", "language/ruby/tests/run.rb"),
        ROOT,
    )


def elixir_suite() -> Command:
    return Command(
        "python -m scripts.labs.elixir_behavior_suite",
        (sys.executable, "-m", "scripts.labs.elixir_behavior_suite"),
        ROOT,
    )


def cpp_suite() -> Command:
    return Command(
        "python -m scripts.labs.cpp_behavior_suite",
        (sys.executable, "-m", "scripts.labs.cpp_behavior_suite"),
        ROOT,
    )


def php_suite() -> Command:
    return Command(
        "php language/php/tests/run.php",
        ("php", "language/php/tests/run.php"),
        ROOT,
    )


def csharp_suite() -> Command:
    return Command(
        "dotnet run --project language/csharp/Praxo.Tests",
        ("dotnet", "run", "--project", "language/csharp/Praxo.Tests"),
        ROOT,
    )


def lua_suite() -> Command:
    return Command(
        "lua language/lua/tests/run.lua",
        ("lua", "language/lua/tests/run.lua"),
        ROOT,
    )


def r_suite() -> Command:
    return Command(
        "Rscript language/r/tests/run_tests.R",
        ("Rscript", "language/r/tests/run_tests.R"),
        ROOT,
    )


def c_suite() -> Command:
    return Command(
        "ctest --test-dir language/c/build --output-on-failure",
        ("ctest", "--test-dir", "language/c/build", "--output-on-failure"),
        ROOT,
    )

auth = java_test("AgentAuthorizationSelfTest")
lifecycle = java_test("AgentLifecycleSelfTest")
guardrail = java_test("AgentGuardrailSelfTest")
schema = java_class_test("com.axisvela.praxo.jsonschema.JsonSchemaSelfTest")
checkpoint = java_class_test("com.axisvela.praxo.checkpoint.CheckpointSelfTest")
pii = java_class_test("com.axisvela.praxo.middleware.PiiMiddlewareSelfTest")
stream = java_test("AgentStreamSelfTest")
concurrency = java_test("AgentConcurrencySelfTest")
adapter = java_class_test(
    "com.axisvela.praxo.adapters.OpenAICompatibleSelfTest",
    "--add-modules",
    "jdk.httpserver",
)
fortran = native_suite("fortran")
cobol = native_suite("cobol")
erlang = native_suite("erlang")
ruby = ruby_suite()
elixir = elixir_suite()
cpp = cpp_suite()
php = php_suite()
csharp = csharp_suite()
lua = lua_suite()
r = r_suite()
c = c_suite()

__all__ = [
"Scenario", "ROOT", "SCHEMA", "auth", "lifecycle", "guardrail", "schema",
"checkpoint", "pii", "stream", "concurrency", "adapter", "fortran",
"cobol", "erlang", "ruby", "elixir", "cpp", "php", "csharp", "lua", "r", "c",
"go_test", "python_test", "typescript_test", "java_class_test", "java_test",
"rust_test", "rust_hitl_test", "native_suite", "ruby_suite", "elixir_suite",
"cpp_suite", "php_suite", "csharp_suite", "lua_suite", "r_suite", "c_suite",
]
