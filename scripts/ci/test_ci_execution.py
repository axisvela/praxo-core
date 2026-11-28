import itertools
import json
import re
import unittest
from functools import lru_cache

import yaml

from scripts.ci import ci_changes
from scripts.ci import sync_ci_routing
from scripts.ci.test_ci_changes import classify, condition_matches, selected_jobs, workflow_triggered


@lru_cache(maxsize=None)
def workflow(name):
    return yaml.safe_load((sync_ci_routing.WORKFLOWS / name).read_text(encoding="utf-8"))


def active_steps(files, name, job, event="pull_request"):
    values = classify(files, name, event)
    if not condition_matches(workflow(name)["jobs"][job]["if"], values):
        return []
    return [step for step in workflow(name)["jobs"][job]["steps"]
            if "if" not in step or condition_matches(step["if"], values)]


def matrix_size(matrix):
    axes = {key: value for key, value in matrix.items() if key not in {"include", "exclude"}}
    rows = [dict(zip(axes, values)) for values in itertools.product(*axes.values())] if axes else []
    rows = [row for row in rows if not any(all(row.get(key) == value for key, value in exclusion.items())
                                         for exclusion in matrix.get("exclude", []))]
    extras = sum(not any(all(key not in axes or row[key] == value for key, value in inclusion.items())
                         for row in rows) for inclusion in matrix.get("include", []))
    return len(rows) + extras


def runner_counts(files, event="pull_request"):
    result = {}
    for path in sorted(sync_ci_routing.WORKFLOWS.glob("ci*.yml")):
        if not workflow_triggered(files, path.name, event):
            continue
        jobs = workflow(path.name)["jobs"]
        selected = selected_jobs(files, path.name, event)
        count = int("changes" in jobs)
        for name, job in jobs.items():
            if name in selected or job.get("if") == "always()":
                count += matrix_size(job["strategy"]["matrix"]) if "matrix" in job.get("strategy", {}) else 1
        result[path.name] = count
    for name in ("docs.yml", "language-mirrors.yml"):
        if workflow_triggered(files, name, event):
            result[name] = 1 + int(event == "push")
    return result


class CiExecutionTests(unittest.TestCase):
    def test_nested_markdown_only_runs_docs(self):
        for file in ("language/python/Tutorial/bug-repair/README.md",
                     "language/php/examples/retry/README.md", "language/java/application/README.md"):
            with self.subTest(file=file):
                self.assertEqual(json.loads(classify([file])["languages"]), [])
                for path in sync_ci_routing.WORKFLOWS.glob("ci*.yml"):
                    expected = {"scenario-catalog"} if (
                        path.name == "ci-tutorials.yml" and "/Tutorial/" in file
                    ) else set()
                    self.assertEqual(selected_jobs([file], path.name), expected)
        self.assertEqual(classify(["spec/agent.md"])["full"], "true")
        self.assertIn("python-conformance", selected_jobs(["language/python/src/prompts/repair.md"], "ci-python.yml"))
        self.assertIn("python-conformance", selected_jobs([
            "language/python/Tutorial/bug-repair/README.md", "language/python/praxo/agent.py"], "ci-python.yml"))

    def test_ci_is_a_small_gate_and_portfolio_is_scheduled(self):
        self.assertEqual(set(workflow("ci.yml")["jobs"]), {"changes", "script-tests"})
        portfolio = workflow("portfolio.yml")
        events = portfolio.get("on", portfolio.get(True))
        self.assertEqual(set(events), {"schedule", "workflow_dispatch"})
        for job in portfolio["jobs"].values():
            self.assertNotIn("if", job)
            self.assertNotIn("needs", job)
        tutorials = workflow("ci-tutorials.yml")["jobs"]
        self.assertEqual(set(tutorials), {"changes", "scenario-catalog", "shared-service-integrations"})

    def test_ordinary_sdk_events_have_dedicated_owners(self):
        portfolio = yaml.safe_load((sync_ci_routing.WORKFLOWS / "portfolio.yml").read_text(encoding="utf-8"))["jobs"]
        for path in sync_ci_routing.WORKFLOWS.glob("ci-*.yml"):
            for name in workflow(path.name)["jobs"]:
                if name != "changes" and name in portfolio:
                    self.assertNotIn("if", portfolio[name])
                    self.assertNotIn("needs", portfolio[name])
        for language, file in (("php", "src/Agent.php"), ("python", "praxo/agent.py"), ("java", "src/main/java/Agent.java")):
            for event in ("push", "pull_request"):
                files = [f"language/{language}/{file}"]
                self.assertEqual(workflow_triggered(files, "ci.yml", event), event == "push")
                self.assertEqual(selected_jobs(files, "ci.yml", event), set())
        self.assertIn("example-sdks", portfolio)

    def test_release_workflows_receive_same_commit_main_push_checks(self):
        for name in ("ci.yml", "docs.yml"):
            config = workflow(name)
            events = config.get("on", config.get(True))
            self.assertEqual(events["push"], {"branches": ["main"]}, name)
            self.assertIn("paths", events["pull_request"], name)
        changes = workflow("ci.yml")["jobs"]["changes"]
        self.assertNotIn("if", changes)
        self.assertTrue(any(step.get("run") == "python -m scripts.ci.ci_changes" for step in changes["steps"]))
        self.assertTrue(any(step.get("run") == "python -m scripts.ci.sync_ci_routing --check" for step in changes["steps"]))
        for file in ("README.md", "docs/getting-started/index.md", "spec/languages.md",
                     "language/php/src/Agent.php", "language/python/praxo/agent.py",
                     "language/java/application/src/main/java/App.java"):
            with self.subTest(file=file):
                self.assertEqual(runner_counts([file], "push")["ci.yml"], 1)
                self.assertEqual(selected_jobs([file], "ci.yml", "push"), set())

    def test_portfolio_unique_commands_moved_to_ordinary_owners(self):
        cases = {"ci-extended.yml": {"php-conformance": "php language/php/tests/plugin_process.php",
                                     "php-windows-conformance": "php language/php/tests/plugin_process.php"},
                 "ci-java.yml": {"java-conformance": "com.axisvela.praxo.plugin.ProcessHostSelfTest"},
                 "ci-native.yml": {"cpp-conformance": "praxo-cpp-plugin-process"},
                 "ci-optional.yml": {"julia-conformance": "language/julia/tests/plugin_process.jl"},
                 "ci-optional2.yml": {"nim-conformance": "praxo-nim-plugin-process",
                                       "d-conformance": "./build/plugin_process_tests",
                                       "zig-conformance": "zig test src/plugin_process.zig"}}
        for name, jobs in cases.items():
            for job, command in jobs.items():
                self.assertIn(command, str(workflow(name)["jobs"][job]))
        for name, job in workflow("ci.yml")["jobs"].items():
            owners = [workflow(path.name)["jobs"][name] for path in sync_ci_routing.WORKFLOWS.glob("ci-*.yml")
                      if name != "changes" and name in workflow(path.name)["jobs"]]
            if owners:
                commands = {step["run"].strip() for step in job["steps"] if "run" in step}
                owned = {step["run"].strip() for owner in owners for step in owner["steps"] if "run" in step}
                self.assertTrue(commands <= owned, (name, commands - owned))

    def test_examples_execute_only_the_changed_sdk(self):
        for language, file in (("php", "examples/retry/retry.php"),
                               ("python", "examples/structured-output-app/app.py")):
            files = [f"language/{language}/{file}"]
            steps = active_steps(files, "ci-examples.yml", "example-sdks")
            text = "\n".join(str(step) for step in steps)
            self.assertEqual(set(re.findall(r"language/([a-z]+)/", text)), {language})
            actions = {step["uses"] for step in steps if "uses" in step}
            allowed = {"actions/checkout@v4", "actions/setup-python@v5"}
            if language == "php":
                allowed.add("shivammathur/setup-php@v2")
                self.assertIn("php language/php/examples/mcp/mcp.php", text)
            else:
                self.assertIn("language/python/examples/structured-output-app", text)
                self.assertIn("python -m unittest test_governance.py", text)
            self.assertTrue(actions <= allowed, actions)
            self.assertNotIn("apt-get install", text)
            self.assertNotIn("shared-service-integrations", selected_jobs(files, "ci-tutorials.yml"))

    def test_labs_intersect_languages_and_skip_unrelated_preparation(self):
        files = ["pkg/agent/agent.go"]
        values = classify(files, "ci-labs.yml")
        self.assertEqual(values["labs"], "true")
        self.assertEqual(json.loads(values["behavior_languages"]), ["go"])
        self.assertEqual(json.loads(values["compatibility_languages"]), [])
        steps = active_steps(files, "ci-labs.yml", "behavior-lab")
        text = str(steps)
        self.assertIn('--languages "$LAB_LANGUAGES"', text)
        self.assertIn("actions/setup-go@v5", text)
        for unrelated in ("npm ci", "mvn -q", "cmake --build", "setup-node@", "setup-java@",
                          "rust-toolchain@", "setup-dotnet@", "setup-beam@", "setup-php@",
                          "gh-actions-lua@", "setup-ruby@"):
            self.assertNotIn(unrelated, text)
        env = workflow("ci-labs.yml")["jobs"]["behavior-lab"]["env"]["LAB_LANGUAGES"]
        self.assertIn("fromJSON(needs.changes.outputs.behavior_languages)", env)
        self.assertEqual(active_steps(files, "ci-labs.yml", "compatibility-lab"), [])

    def test_lab_script_changes_do_not_expand_the_full_portfolio(self):
        files = ["scripts/labs/test_behavior_lab.py"]
        values = classify(files, "ci-labs.yml")
        self.assertEqual(values["full"], "false")
        self.assertEqual(values["labs"], "true")
        self.assertEqual(json.loads(values["languages"]), [])
        self.assertIn("behavior-lab", selected_jobs(files, "ci-labs.yml"))
        for workflow_name in ("ci-python.yml", "ci-java.yml", "ci-extended.yml", "ci-applications.yml"):
            self.assertEqual(selected_jobs(files, workflow_name), set())

    def test_all_selected_runtime_jobs_stay_within_the_changed_sdk(self):
        for language, file in (("php", "src/Agent.php"), ("python", "praxo/agent.py")):
            files = [f"language/{language}/{file}"]
            allowed_actions = {"actions/checkout@v4", "actions/setup-python@v5", "actions/upload-artifact@v4"}
            if language == "php":
                allowed_actions.add("shivammathur/setup-php@v2")
            for path in sync_ci_routing.WORKFLOWS.glob("ci*.yml"):
                for job in selected_jobs(files, path.name):
                    for step in active_steps(files, path.name, job):
                        with self.subTest(language=language, workflow=path.name, job=job, step=step):
                            self.assertTrue(set(re.findall(r"language/([a-z]+)/", str(step))) <= {language})
                            if "uses" in step:
                                self.assertIn(step["uses"], allowed_actions)

    def test_full_and_scheduled_labs_retain_all_runtimes(self):
        for event in ("workflow_dispatch", "schedule"):
            values = classify([], "ci-labs.yml", event)
            for lab, languages in ci_changes.LAB_LANGUAGES.items():
                self.assertEqual(json.loads(values[f"{lab}_languages"]), list(languages))
                job = workflow("ci-labs.yml")["jobs"][lab + "-lab"]
                self.assertEqual(active_steps([], "ci-labs.yml", lab + "-lab", event), job["steps"])
        job = workflow("ci-examples.yml")["jobs"]["example-sdks"]
        self.assertEqual(active_steps([], "ci-examples.yml", "example-sdks", "workflow_dispatch"), job["steps"])

    def test_php_package_scripts_are_scoped_and_tests_are_not_swallowed(self):
        job = workflow("ci-extended.yml")["jobs"]["php-package"]
        self.assertEqual(job["runs-on"], "ubuntu-latest")
        setup = next(step for step in job["steps"] if step.get("uses", "").startswith("shivammathur/setup-php@"))
        self.assertEqual(setup["with"]["tools"], "composer")
        command = next(step for step in job["steps"] if step.get("run") == "python -m scripts.languages.php.test_php_package")
        self.assertEqual(command["env"], {"PRAXO_PHP": "php", "PRAXO_COMPOSER": "composer"})
        for file, language in (("scripts/languages/php/test_php_package.py", "php"),
                               ("scripts/languages/ocaml/test_ocaml_package.py", "ocaml")):
            values = classify([file])
            self.assertEqual(values["full"], "false")
            self.assertEqual(json.loads(values["languages"]), [language])
            if language == "php":
                self.assertIn("php-package", selected_jobs([file], "ci-extended.yml"))
                for name in ("ci.yml", "ci-python.yml", "ci-java.yml", "ci-native.yml"):
                    self.assertFalse(workflow_triggered([file], name), name)
            else:
                self.assertIn("ocaml-conformance", selected_jobs([file], "ci-optional2.yml"))
                self.assertTrue(workflow_triggered([file], "ocaml-package.yml"))
                self.assertFalse(workflow_triggered([file], "ci-extended.yml"))
        docs = workflow("docs.yml")["jobs"]["build"]["steps"]
        self.assertFalse(any('discover -s scripts -t . -p "test_*.py"' in step.get("run", "") for step in docs))
        self.assertTrue(any("test_ci_execution" in step.get("run", "") for step in docs))
        fallback = workflow("ci.yml")["jobs"]["script-tests"]
        self.assertEqual(fallback["if"], "needs.changes.outputs.full == 'true'")
        self.assertTrue(any('discover -s scripts -t . -p "test_*.py"' in step.get("run", "") for step in fallback["steps"]))
        self.assertTrue(any(step.get("with", {}).get("tools") == "composer" for step in fallback["steps"]))

    def test_matrix_counts_include_extra_java_version(self):
        self.assertEqual(matrix_size({"os": ["linux", "windows", "macos"], "java": ["21"],
                                      "include": [{"os": "linux", "java": "23"}]}), 4)
        self.assertEqual(matrix_size({"os": ["linux", "windows"], "node": ["20", "22"]}), 4)
        with self.assertRaisesRegex(ValueError, "custom step conditions"):
            sync_ci_routing.scoped_steps("    steps:\n      - run: php language/php/tests/run.php\n        if: always()\n")

    def test_each_portfolio_sdk_keeps_an_ordinary_conformance_owner(self):
        portfolio = yaml.safe_load((sync_ci_routing.WORKFLOWS / "portfolio.yml").read_text(encoding="utf-8"))["jobs"]
        for name in portfolio:
            if not name.endswith("-conformance") or name == "spec-conformance":
                continue
            language = name.removesuffix("-conformance").removesuffix("-windows")
            files = [f"language/{language}/src/routing-probe"]
            owners = [path.name for path in sync_ci_routing.WORKFLOWS.glob("ci*.yml")
                      if name in selected_jobs(files, path.name)]
            self.assertEqual(len(owners), 1, (name, owners))

    def test_representative_runner_counts(self):
        cases = {"README.md": (1, 3), "language/python/Tutorial/bug-repair/README.md": (5, 8),
                 "language/php/src/Agent.php": (9, 13), "language/python/praxo/agent.py": (9, 13),
                 "language/java/application/src/main/java/App.java": (3, 7),
                 "language/php/examples/consumer/composer.json": (10, 13),
                 "scripts/labs/test_behavior_lab.py": (4, 6)}
        for file, (pull_request, push) in cases.items():
            with self.subTest(file=file):
                self.assertEqual(sum(runner_counts([file]).values()), pull_request)
                self.assertEqual(sum(runner_counts([file], "push").values()), push)


if __name__ == "__main__":
    unittest.main()
