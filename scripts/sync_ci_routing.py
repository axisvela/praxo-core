from __future__ import annotations

import argparse
import re
from pathlib import Path

from ci_changes import (
    CI_SCRIPTS, DISCOVERY_INPUTS, DOCS_SCRIPTS, DOC_MARKDOWN_PATTERNS,
    LAB_LANGUAGES, LANGUAGE_DOC_FILES, LANGUAGE_SCRIPTS,
)

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github/workflows"
SHARED = ["spec/**", "scripts/**", "pkg/**", "internal/**", "cmd/**",
          "bindings/**", "adapters/**", "go.mod", "go.sum", "VERSION", "Makefile",
          ".github/actions/**"]


def jobs(body):
    return re.findall(r"^  ([\w-]+):\n(.*?)(?=^  [\w-]+:|\Z)",
                      body.split("\njobs:\n", 1)[1], re.M | re.S)


def languages(name, body):
    found = set(re.findall(r"language/([a-z-]+)(?:/|\s|$)", body))
    for selection in re.findall(r"--languages ([a-z,]+)", body):
        found.update(selection.split(","))
    match = re.fullmatch(r"current-([a-z]+)-consumer", name)
    if match:
        found.add(match[1])
    for script, language in LANGUAGE_SCRIPTS.items():
        if script in body:
            found.add(language)
    if name.removesuffix("-lab") in LAB_LANGUAGES:
        found.update(LAB_LANGUAGES[name.removesuffix("-lab")])
    return found


def selection(deps, output="languages"):
    return "needs.changes.outputs.full == 'true' || " + " || ".join(
        f"contains(fromJSON(needs.changes.outputs.{output}), '{language}')" for language in sorted(deps))


def step_languages(step):
    deps = languages("", step)
    actions = {"setup-go@": {"go"}, "setup-node@": {"typescript"}, "setup-java@": {"java"},
               "rust-toolchain@": {"rust"}, "setup-dotnet@": {"csharp"}, "setup-php@": {"php"},
               "setup-ruby@": {"ruby"}, "setup-beam@": {"elixir", "erlang"}, "gh-actions-lua@": {"lua"}}
    for action, required in actions.items():
        if action in step:
            deps.update(required)
    if "apt-get update" in step and "apt-get install" not in step:
        deps.update({"c", "cpp", "fortran", "cobol", "lua", "r"})
    if "apt-get install" in step:
        for package, required in {"gfortran": {"fortran"}, "gnucobol": {"cobol"},
                                  "r-base": {"r"}, "lua5.4": {"lua"},
                                  "g++ cmake ninja-build": {"c", "cpp", "fortran", "cobol"}}.items():
            if package in step:
                deps.update(required)
    return deps


def scoped_steps(job, output="languages"):
    header, steps = job.split("    steps:\n", 1)
    result = []
    for step in re.findall(r"^      - .*?(?=^      - |\Z)", steps, re.M | re.S):
        deps = step_languages(step)
        if deps:
            existing = re.search(r"^        if: (.+)$", step, re.M)
            if existing and not existing[1].startswith("needs.changes.outputs."):
                raise ValueError("Preserve custom step conditions explicitly before scoping")
            step = re.sub(r"^        if: needs.changes.outputs.*\n", "", step, flags=re.M)
            first, rest = step.split("\n", 1)
            step = first + "\n        if: " + selection(deps, output) + "\n" + rest
        result.append(step)
    return header + "    steps:\n" + "".join(result)


def render(path):
    body = path.read_text(encoding="utf-8")
    original_jobs = jobs(body)
    portfolio = set()
    if path.name == "ci.yml":
        portfolio = {name for owner in WORKFLOWS.glob("ci-*.yml")
                     for name, _ in jobs(owner.read_text(encoding="utf-8"))}
        portfolio.add("example-sdks")
    owned = set()
    for name, job in original_jobs:
        if name != "changes" and name not in portfolio:
            owned.update(languages(name, job))
    workflow = f".github/workflows/{path.name}"
    targeted = {
        "ci-applications.yml": [
            "language/*/application/**", "language/cpp/CMakeLists.txt",
            "language/ruby/lib/**", "pkg/**", "internal/**", "cmd/**",
            "bindings/**", "adapters/**", "go.mod", "go.sum", "VERSION",
            "Makefile", workflow,
        ],
        "ci-tutorials.yml": [
            "language/*/Tutorial/**", "docs/**/agent-scenarios.md",
            "docs/**/tutorial-catalog.md", "docs/**/tutorial-plan.md",
            "mkdocs.yml", workflow,
        ],
        "ci-examples.yml": [
            "language/*/examples/**", "!language/*/examples/consumer/**", workflow,
        ],
        "ci-labs.yml": [*SHARED, "!spec/languages.md",
                        *[f"!{script}" for script in sorted(DOCS_SCRIPTS | CI_SCRIPTS)], workflow],
    }.get(path.name)
    if targeted is not None:
        patterns = targeted
    else:
        patterns = SHARED + [f"language/{language}/**" for language in sorted(owned)]
        if {"matlab", "octave"} & owned:
            patterns.append("language/matlab-octave-core/**")
        if {"csharp", "powershell", "fsharp"} & owned:
            patterns.append("global.json")
        if path.name == "ci.yml":
            patterns += ["api/**", "benchmarks/**", "tests/**", "*.go", ".github/**"]
        patterns.append(workflow)
        patterns += [f"!{script}" for script in sorted(DOCS_SCRIPTS)]
        if path.name != "ci.yml":
            patterns += [f"!{script}" for script in sorted(CI_SCRIPTS)]
        patterns += [f"!{name}" for name in sorted(DISCOVERY_INPUTS)]
        patterns += [f"!language/**/{name}" for name in sorted(LANGUAGE_DOC_FILES)]
        patterns.append("!language/*/application/**")
        patterns += [f"!{pattern}" for pattern in DOC_MARKDOWN_PATTERNS]
        patterns += [f"!{script}" for script, language in sorted(LANGUAGE_SCRIPTS.items()) if language not in owned]
    paths = "    paths:\n" + "".join(f'      - "{p}"\n' for p in dict.fromkeys(patterns))
    push_paths = "" if path.name == "ci.yml" else paths
    events = "on:\n  push:\n    branches: [main]\n" + push_paths + "  pull_request:\n" + paths
    body = re.sub(r"on:\n.*?(?=  workflow_dispatch:)", lambda _: events, body, count=1, flags=re.S)
    concurrency = ("concurrency:\n"
                   "  group: ${{ github.workflow }}-${{ github.event_name }}-${{ github.event.pull_request.number || github.ref }}\n"
                   "  cancel-in-progress: ${{ github.event_name == 'pull_request' || github.event_name == 'push' }}\n\n")
    body = re.sub(r"^concurrency:\n.*?(?=^\w)", "", body, flags=re.M | re.S)
    body = body.replace("\njobs:\n", "\n" + concurrency + "jobs:\n", 1)
    changes = """  changes:
    runs-on: ubuntu-latest
    outputs:
      full: ${{ steps.filter.outputs.full }}
      core: ${{ steps.filter.outputs.core }}
      docs: ${{ steps.filter.outputs.docs }}
      examples: ${{ steps.filter.outputs.examples }}
      consumers: ${{ steps.filter.outputs.consumers }}
      adapters: ${{ steps.filter.outputs.adapters }}
      languages: ${{ steps.filter.outputs.languages }}
      applications: ${{ steps.filter.outputs.applications }}
      tutorials: ${{ steps.filter.outputs.tutorials }}
      example_languages: ${{ steps.filter.outputs.example_languages }}
      labs: ${{ steps.filter.outputs.labs }}
      compatibility_languages: ${{ steps.filter.outputs.compatibility_languages }}
      behavior_languages: ${{ steps.filter.outputs.behavior_languages }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - id: filter
        env:
          EVENT_NAME: ${{ github.event_name }}
          REF_TYPE: ${{ github.ref_type }}
          PR_BASE_SHA: ${{ github.event.pull_request.base.sha }}
          PUSH_BEFORE: ${{ github.event.before }}
          HEAD_SHA: ${{ github.sha }}
""" + f"          WORKFLOW_FILE: .github/workflows/{path.name}\n" + "        run: python scripts/ci_changes.py\n"
    if path.name == "ci.yml":
        changes += "      - run: python scripts/check_ci_workflow_coverage.py\n"
        changes += "      - run: python scripts/sync_ci_routing.py --check\n"
        changes += "      - run: python -m unittest discover -s scripts -p test_ci_changes.py -v\n"
        changes += "      - uses: actions/setup-python@v5\n        with:\n          python-version: '3.12'\n"
        changes += "      - run: python -m pip install PyYAML==6.0.3\n"
        changes += "      - run: python -m unittest discover -s scripts -p test_ci_execution.py -v\n"
    rendered = []
    for name, job in original_jobs:
        if name == "changes":
            continue
        if re.search(r"^    if: always\(\)$", job, re.M):
            rendered.append(f"  {name}:\n{job}")
            continue
        needs = re.search(r"^    needs:(.*)$", job, re.M)
        if needs and needs[1].strip() != "changes":
            raise ValueError(f"{path.name}/{name}: preserve custom job dependencies explicitly")
        deps = languages(name, job)
        if deps:
            output = "applications" if path.name == "ci-applications.yml" else "languages"
            if path.name == "ci-tutorials.yml":
                output = "tutorials"
            if path.name == "ci-examples.yml" and name == "example-sdks":
                output = "example_languages"
            condition = "needs.changes.outputs.full == 'true' || " + " || ".join(
                f"contains(fromJSON(needs.changes.outputs.{output}), '{lang}')" for lang in sorted(deps))
            if "go" in deps and output == "languages":
                condition += " || needs.changes.outputs.core == 'true'"
        else:
            existing = re.search(r"^    if: (.+)$", job, re.M)
            condition = existing[1] if existing else "needs.changes.outputs.full == 'true' || needs.changes.outputs.core == 'true'"
            if "needs.changes.outputs.full == 'true'" not in condition:
                condition = "needs.changes.outputs.full == 'true' || " + condition
            if path.name == "ci.yml" and name in {"published-consumer", "benchmarks", "race", "fuzz", "quality"}:
                condition = "needs.changes.outputs.full == 'true' || needs.changes.outputs.core == 'true'"
            if name == "scenario-catalog":
                condition = "needs.changes.outputs.full == 'true' || needs.changes.outputs.core == 'true' || needs.changes.outputs.docs == 'true' || needs.changes.outputs.examples == 'true' || needs.changes.outputs.languages != '[]'"
        if name in portfolio or name == "shared-service-integrations":
            condition = "needs.changes.outputs.full == 'true'"
        if path.name == "ci-labs.yml" and name.endswith("-lab"):
            output = name.removesuffix("-lab") + "_languages"
            condition = (f"needs.changes.outputs.full == 'true' || "
                         f"(needs.changes.outputs.labs == 'true' && needs.changes.outputs.{output} != '[]')")
            job = re.sub(r'--languages (?:[a-z,]+|"\$LAB_LANGUAGES")', '--languages "$LAB_LANGUAGES"', job)
            job = re.sub(r"^      LAB_LANGUAGES:.*\n", "", job, flags=re.M)
            if "    env:\n" not in job:
                job = job.replace("    steps:\n", "    env:\n    steps:\n", 1)
            job = job.replace("    env:\n", f"    env:\n      LAB_LANGUAGES: ${{{{ join(fromJSON(needs.changes.outputs.{output}), ',') }}}}\n", 1)
            job = scoped_steps(job, output)
        if path.name == "ci-examples.yml" and name == "example-sdks":
            job = scoped_steps(job, "example_languages")
        job = re.sub(r"^    (?:needs|if):.*\n", "", job, flags=re.M)
        rendered.append(f"  {name}:\n    needs: changes\n    if: {condition}\n{job}")
    return body.split("\njobs:\n", 1)[0] + "\njobs:\n" + changes + "\n" + "".join(rendered)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    stale = []
    for path in sorted(WORKFLOWS.glob("ci*.yml")):
        updated = render(path)
        if updated != path.read_text(encoding="utf-8"):
            stale.append(path.name)
            if not args.check:
                path.write_text(updated, encoding="utf-8", newline="\n")
    if args.check and stale:
        raise SystemExit("CI routing needs regeneration: " + ", ".join(stale))
    print("CI routing " + ("checked" if args.check else "generated"))


if __name__ == "__main__":
    main()
