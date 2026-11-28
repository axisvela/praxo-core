import json
import os
import re
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import ci_changes
import sync_ci_routing


ROOT = Path(__file__).resolve().parents[1]


def classify(files, workflow="ci.yml", event="pull_request"):
    env = dict(os.environ)
    for key in ("EVENT_NAME", "REF_TYPE", "WORKFLOW_FILE"):
        env.pop(key, None)
    env.pop("GITHUB_OUTPUT", None)
    env["EVENT_NAME"] = event
    env["WORKFLOW_FILE"] = ".github/workflows/" + workflow
    env["CI_CHANGED_FILES"] = "\n".join(files)
    result = subprocess.run(
        [sys.executable, "scripts/ci_changes.py"],
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr)
    values = {}
    for line in result.stdout.splitlines():
        key, value = line.split("=", 1)
        values[key] = value
    return values


def workflow_triggered(files, workflow, event="pull_request"):
    path = ROOT / ".github/workflows" / workflow
    body = path.read_text(encoding="utf-8")
    if event in {"workflow_dispatch", "schedule"}:
        return f"  {event}:" in body
    block = re.split(r"\n  \w", body.split(f"  {event}:\n", 1)[1], maxsplit=1)[0]
    if "paths:" not in block:
        return True
    if "paths: *docs-paths" in block:
        block = body.split("paths: &docs-paths\n", 1)[1].split("\n  pull_request:", 1)[0]
    paths = re.findall(r'^      - "([^"]+)"$', block, re.M)
    for file in files:
        included = False
        for pattern in paths:
            exclude = pattern.startswith("!")
            pattern = pattern.removeprefix("!")
            expression = re.escape(pattern).replace(r"\*\*/", "(?:.*/)?").replace(r"\*\*", ".*").replace(r"\*", "[^/]*")
            if re.fullmatch(expression, file):
                included = not exclude
        if included:
            return True
    return False


def condition_matches(condition, values):
    if condition == "always()":
        return True
    for term in condition.split(" || "):
        contains = re.fullmatch(r"contains\(fromJSON\(needs.changes.outputs.(\w+)\), '([^']+)'\)", term)
        comparison = re.fullmatch(r"needs.changes.outputs.(\w+) (==|!=) '([^']*)'", term)
        if contains:
            matched = contains[2] in json.loads(values[contains[1]])
        elif comparison:
            equal = values[comparison[1]] == comparison[3]
            matched = equal if comparison[2] == "==" else not equal
        else:
            raise AssertionError("Unsupported routing condition: " + term)
        if matched:
            return True
    return False


def selected_jobs(files, workflow, event="pull_request"):
    if not workflow_triggered(files, workflow, event):
        return set()
    path = ROOT / ".github/workflows" / workflow
    body = path.read_text(encoding="utf-8")
    values = classify(files, workflow, event)
    selected = set()
    for name, job in sync_ci_routing.jobs(body):
        if name == "changes":
            continue
        condition = re.search(r"^    if: (.+)$", job, re.M)[1]
        if condition == "always()":
            continue
        if condition_matches(condition, values):
            selected.add(name)
    return selected


class CiChangesTests(unittest.TestCase):
    def test_language_change_does_not_run_core(self):
        values = classify(["language/python/praxo/agent.py"])
        self.assertEqual(values["core"], "false")
        self.assertEqual(json.loads(values["languages"]), ["python"])

    def test_core_go_change_runs_core(self):
        values = classify(["pkg/agent/agent.go"])
        self.assertEqual(values["core"], "true")
        self.assertEqual(json.loads(values["languages"]), [])

    def test_example_go_change_does_not_run_core(self):
        values = classify(["language/go/examples/embedded-service/main.go"])
        self.assertEqual(values["examples"], "true")
        self.assertEqual(values["core"], "false")

    def test_consumer_change_does_not_run_core(self):
        values = classify(["language/python/examples/consumer/starter.py"])
        self.assertEqual(values["consumers"], "false")
        self.assertEqual(values["core"], "false")
        self.assertEqual(json.loads(values["languages"]), ["python"])

    def test_go_consumer_change_does_not_run_core(self):
        values = classify(["language/go/examples/consumer-go/main.go"])
        self.assertEqual(values["consumers"], "true")
        self.assertEqual(values["core"], "false")

    def test_spec_change_runs_full_matrix(self):
        values = classify(["spec/vectors/agent.json"])
        self.assertEqual(values["full"], "true")
        self.assertEqual(values["core"], "true")

    def test_readme_and_docs_do_not_run_test_workflows(self):
        for file in ("README.md", "docs/getting-started/index.md"):
            for path in sync_ci_routing.WORKFLOWS.glob("ci*.yml"):
                with self.subTest(file=file, workflow=path.name):
                    self.assertEqual(selected_jobs([file], path.name), set())

    def test_php_source_selects_php_gates_not_sibling_sdks(self):
        files = ["language/php/src/Agent.php"]
        selected = selected_jobs(files, "ci-extended.yml")
        self.assertIn("php-conformance", selected)
        self.assertIn("current-php-consumer", selected)
        self.assertNotIn("ruby-conformance", selected)
        self.assertNotIn("elixir-conformance", selected)
        self.assertEqual(selected_jobs(files, "ci-java.yml"), set())
        self.assertEqual(selected_jobs(files, "ci-applications.yml"), {"php-reference-applications"})
        tutorials = selected_jobs(files, "ci-tutorials.yml")
        self.assertTrue(any(name.startswith("php-") for name in tutorials))
        self.assertFalse(any(name.startswith("java-") for name in tutorials))

    def test_java_application_does_not_run_sdk_or_consumers(self):
        files = ["language/java/application/src/main/java/App.java"]
        self.assertEqual(selected_jobs(files, "ci-applications.yml"), {"java-ai-commerce"})
        for workflow in ("ci.yml", "ci-java.yml", "ci-examples.yml", "ci-tutorials.yml"):
            self.assertEqual(selected_jobs(files, workflow), set())

    def test_workflow_change_is_local_not_global_full(self):
        files = [".github/workflows/ci-java.yml"]
        self.assertIn("java-conformance", selected_jobs(files, "ci-java.yml"))
        for workflow in ("ci.yml", "ci-extended.yml", "ci-tutorials.yml", "ci-applications.yml"):
            self.assertEqual(selected_jobs(files, workflow), set())
        self.assertEqual(classify([".github/workflows/php-release.yml"])["full"], "false")

    def test_shared_spec_and_manual_dispatch_keep_every_gate(self):
        for path in sync_ci_routing.WORKFLOWS.glob("ci*.yml"):
            body = path.read_text(encoding="utf-8")
            expected = {name for name, job in sync_ci_routing.jobs(body)
                        if name != "changes" and not re.search(r"^    if: always\(\)$", job, re.M)}
            with self.subTest(workflow=path.name):
                self.assertEqual(selected_jobs(["spec/vectors/agent.json"], path.name), expected)
                self.assertEqual(selected_jobs([], path.name, "workflow_dispatch"), expected)

    def test_shared_runtime_dependencies(self):
        cases = [
            ("language/c/src/agent.c", "ci-optional2.yml", "objc-conformance"),
            ("language/csharp/Praxo.Core/Agent.cs", "ci-additional2.yml", "powershell-examples"),
            ("language/java/src/main/java/Agent.java", "ci-java.yml", "kotlin-sample"),
            ("language/matlab-octave-core/agent.m", "ci-optional2.yml", "octave-conformance"),
            ("language/dart/lib/agent.dart", "ci-additional.yml", "dart-examples"),
            ("pkg/agent/agent.go", "ci-adapters.yml", "adapters"),
            ("pkg/agent/agent.go", "ci-bridge.yml", "bridge"),
            ("pkg/agent/agent.go", "ci.yml", "race"),
        ]
        for file, workflow, job in cases:
            with self.subTest(file=file, workflow=workflow):
                self.assertIn(job, selected_jobs([file], workflow))

    def test_generated_workflows_are_current_and_fail_closed(self):
        for path in sync_ci_routing.WORKFLOWS.glob("ci*.yml"):
            body = path.read_text(encoding="utf-8")
            with self.subTest(workflow=path.name):
                self.assertEqual(sync_ci_routing.render(path), body)
                self.assertIn("github.event_name == 'push'", body.split("cancel-in-progress:")[1].splitlines()[0])
                for name, job in sync_ci_routing.jobs(body):
                    if name == "changes" or re.search(r"^    if: always\(\)$", job, re.M):
                        continue
                    self.assertIn("    needs: changes\n", job)
                    self.assertIn("needs.changes.outputs.full == 'true'", job.splitlines()[1])

    def test_push_diff_does_not_use_merge_base(self):
        with patch.dict(os.environ, {"EVENT_NAME": "push"}), patch.object(ci_changes.subprocess, "check_output", return_value="file\0") as run:
            self.assertEqual(ci_changes.git_diff("before", "after"), ["file"])
            self.assertEqual(run.call_args.args[0], ["git", "diff", "--name-only", "--no-renames", "-z", "before", "after"])

    def test_pull_request_diff_uses_merge_base(self):
        with patch.dict(os.environ, {"EVENT_NAME": "pull_request"}), patch.object(ci_changes.subprocess, "check_output", return_value="") as run:
            ci_changes.git_diff("base", "head")
            self.assertEqual(run.call_args.args[0], ["git", "diff", "--name-only", "--no-renames", "-z", "base...head"])

    def test_script_and_scheduled_changes_remain_full(self):
        self.assertEqual(classify(["scripts/check_contract.py"])["full"], "true")
        self.assertEqual(classify([], event="schedule")["full"], "true")

    def test_lab_language_arguments_are_dependencies(self):
        self.assertIn("behavior-lab", selected_jobs(["language/php/src/Agent.php"], "ci-labs.yml"))
        self.assertIn("compatibility-lab", selected_jobs(["language/python/praxo/agent.py"], "ci-labs.yml"))

    def test_docs_and_mirror_concurrency_keep_writes_serialized(self):
        workflows = ROOT / ".github/workflows"
        docs = (workflows / "docs.yml").read_text(encoding="utf-8")
        self.assertNotIn("paths:", docs.split("  push:\n", 1)[1].split("  pull_request:", 1)[0])
        self.assertIn('      - "docs/**"', docs.split("  pull_request:\n", 1)[1])
        for name in ("docs.yml", "language-mirrors.yml"):
            body = (workflows / name).read_text(encoding="utf-8")
            concurrency = body.split("concurrency:\n", 1)[1].split("\njobs:", 1)[0]
            self.assertIn("github.event.pull_request.number", concurrency)
            self.assertIn("cancel-in-progress: ${{ github.event_name == 'pull_request' }}", concurrency)

    def test_shared_action_and_dotnet_configuration_dependencies(self):
        self.assertEqual(classify([".github/actions/setup/action.yml"])["full"], "true")
        self.assertIn("powershell-examples", selected_jobs(["global.json"], "ci-additional2.yml"))

    def test_generator_preserves_execution_and_rejects_hidden_job_dependencies(self):
        execution = """    runs-on: ${{ matrix.os }}
    timeout-minutes: 15
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
    steps:
      - uses: actions/checkout@v4
      - run: php language/php/tests/run.php
      - uses: actions/upload-artifact@v4
        if: always()
"""
        workflow = Mock(name="workflow")
        workflow.name = "ci-fixture.yml"
        workflow.read_text.return_value = "name: fixture\non:\n  workflow_dispatch:\njobs:\n  php:\n" + execution
        rendered = sync_ci_routing.render(workflow)
        self.assertIn(execution, rendered)
        self.assertIn("    needs: changes\n", rendered)
        workflow.read_text.return_value = workflow.read_text.return_value.replace("  php:\n", "  php:\n    needs: build\n")
        with self.assertRaisesRegex(ValueError, "preserve custom job dependencies"):
            sync_ci_routing.render(workflow)

    def test_scoped_docs_scripts_skip_runtime_workflows_but_run_docs(self):
        for file in sorted(ci_changes.DOCS_SCRIPTS):
            values = classify([file])
            with self.subTest(file=file):
                self.assertEqual(values["full"], "false")
                self.assertEqual(values["core"], "false")
                self.assertEqual(values["docs"], "true")
                self.assertEqual(json.loads(values["languages"]), [])
                for event in ("push", "pull_request"):
                    self.assertTrue(workflow_triggered([file], "docs.yml", event))
                    for path in sync_ci_routing.WORKFLOWS.glob("ci*.yml"):
                        if path.name == "ci.yml" and event == "push":
                            self.assertTrue(workflow_triggered([file], path.name, event))
                            self.assertEqual(selected_jobs([file], path.name, event), set())
                        else:
                            self.assertFalse(workflow_triggered([file], path.name, event), path.name)

    def test_discovery_metadata_and_generated_entries_do_not_select_sdks(self):
        files = ["language/discovery.json", "language/registry-metadata.json", "spec/languages.md",
                 "language/php/README.md", "language/java/REGISTRY.md",
                 "language/python/llms.txt", "language/csharp/llms.md", "language/perl/README.pod"]
        for file in files:
            values = classify([file])
            with self.subTest(file=file):
                self.assertEqual(values["docs"], "true")
                self.assertEqual(values["full"], "false")
                self.assertEqual(json.loads(values["languages"]), [])
                self.assertEqual(json.loads(values["applications"]), [])
                self.assertTrue(workflow_triggered([file], "docs.yml"))
                self.assertTrue(workflow_triggered([file], "language-mirrors.yml"))
                for path in sync_ci_routing.WORKFLOWS.glob("ci*.yml"):
                    if path.name == "ci-tutorials.yml" and file.startswith("language/") and file.endswith(".md"):
                        self.assertEqual(selected_jobs([file], path.name), {"scenario-catalog"})
                    else:
                        self.assertFalse(workflow_triggered([file], path.name), path.name)

    def test_mixed_metadata_and_source_changes_keep_runtime_gates(self):
        files = ["scripts/docs_hooks.py", "language/php/README.md", "language/php/src/Agent.php"]
        self.assertEqual(classify(files)["full"], "false")
        self.assertIn("php-conformance", selected_jobs(files, "ci-extended.yml"))
        self.assertIn("php-reference-applications", selected_jobs(files, "ci-applications.yml"))
        self.assertNotIn("ruby-conformance", selected_jobs(files, "ci-extended.yml"))
        self.assertIn("csharp-conformance", selected_jobs([
            "language/discovery.json", "language/csharp/Praxo.Core/Praxo.Core.csproj"], "ci-dotnet.yml"))

    def test_unknown_scripts_keep_conservative_full_fanout(self):
        files = ["scripts/new_shared_check.py", "scripts/registry_discovery.py"]
        self.assertEqual(classify(files)["full"], "true")
        for path in sync_ci_routing.WORKFLOWS.glob("ci*.yml"):
            with self.subTest(workflow=path.name):
                self.assertEqual(selected_jobs(files, path.name), selected_jobs([], path.name, "workflow_dispatch"))

    def test_docs_and_mirror_discovery_gates_and_inputs(self):
        inputs = ["scripts/registry_catalog.py", "scripts/registry_discovery.py",
                  "scripts/repository_discovery.py", "scripts/sync_language_registry_docs.py",
                  "scripts/mirror_readme.py", "scripts/test_discovery.py",
                  "language/discovery.json", "language/registry-metadata.json"]
        for workflow in ("docs.yml", "language-mirrors.yml"):
            body = (sync_ci_routing.WORKFLOWS / workflow).read_text(encoding="utf-8")
            self.assertIn("python scripts/repository_discovery.py --check", body)
            for event in ("push", "pull_request"):
                for file in inputs:
                    with self.subTest(workflow=workflow, event=event, file=file):
                        self.assertTrue(workflow_triggered([file], workflow, event))
        docs = (sync_ci_routing.WORKFLOWS / "docs.yml").read_text(encoding="utf-8")
        self.assertIn("python scripts/test_discovery.py -v", docs)
        self.assertIn("python scripts/sync_language_registry_docs.py --check", docs)
        for file in ("language/csharp/Praxo.Core/Praxo.Core.csproj", "language/erlang/src/praxo_core.app.src",
                     "language/ruby/praxo-core.gemspec", "language/perl/Makefile.PL",
                     "language/powershell/praxo-core-ps/praxo-core-ps.psd1"):
            self.assertTrue(workflow_triggered([file], "docs.yml"), file)

    def test_go_core_keeps_reference_application_and_bridge_gates(self):
        for file in ("pkg/agent/agent.go", "go.mod", "go.sum"):
            with self.subTest(file=file):
                self.assertIn("go-ai-ops", selected_jobs([file], "ci-applications.yml"))
                self.assertIn("bridge", selected_jobs([file], "ci-bridge.yml"))
                selected = selected_jobs([file], "ci.yml")
                self.assertTrue({"lisp-bridge", "tcl-bridge", "prolog-bridge", "test", "race"} <= selected)
                self.assertNotIn("csharp-conformance", selected)
        self.assertIn("bridge", selected_jobs(["bindings/shell/praxo-bridge.sh"], "ci-bridge.yml"))

    def test_dotnet_shared_runtime_and_visual_basic_use_actual_paths(self):
        files = ["language/csharp/Praxo.Core/Agent.cs", "language/csharp/samples/VbSample/Program.vb",
                 "language/csharp/samples/VbSample/VbSample.vbproj", "language/fsharp/examples/Program.fs"]
        for file in files:
            with self.subTest(file=file):
                selected = selected_jobs([file], "ci-dotnet.yml")
                self.assertIn("csharp-conformance", selected)
                self.assertEqual(selected_jobs([file], "ci-bridge.yml"), set())
        for workflow in ("ci.yml", "ci-dotnet.yml"):
            body = (sync_ci_routing.WORKFLOWS / workflow).read_text(encoding="utf-8")
            jobs = dict(sync_ci_routing.jobs(body))
            self.assertIn("dotnet run --project language/csharp/samples/VbSample", jobs["csharp-conformance"])
        self.assertIn("powershell-core", selected_jobs([files[0]], "ci-dotnet.yml"))


if __name__ == "__main__":
    unittest.main()
