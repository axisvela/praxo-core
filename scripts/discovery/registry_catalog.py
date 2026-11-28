from pathlib import Path

from scripts.discovery.mirror_readme import _catalog_entries

ROOT = Path(__file__).resolve().parents[2]


def examples_line(directory: Path) -> str:
    relative = directory.relative_to(ROOT).as_posix()
    target = "language/go/examples" if relative == "." else f"{relative}/examples"
    if directory.name == "octave" and not (ROOT / target).is_dir():
        target = "language/matlab/examples"
    if not (ROOT / target).is_dir():
        return "- Examples: no language-specific examples recorded yet.\n"
    return (
        f"- [Examples](https://github.com/axisvela/praxo-core/tree/main/{target}): "
        "runnable language-specific examples; see each README for prerequisites and verification.\n"
    )


def readme_routes(entry: dict) -> str:
    base = "language/go" if entry["dir"] == "." else entry["dir"]
    lines = [f"- Get started, prerequisites, and installation: [language documentation]({entry['docs']})\n"]
    lines.append(examples_line(ROOT / entry["dir"]))
    for folder, label in (("Tutorial", "Scenario tutorials"), ("application", "Reference applications")):
        if (ROOT / base / folder / "README.md").is_file():
            lines.append(f"- [{label}](https://github.com/axisvela/praxo-core/tree/main/{base}/{folder}): read the scope and validation status; source is not portfolio acceptance.\n")
        else:
            lines.append(f"- {label}: no language-specific {'slices' if folder == 'Tutorial' else 'accepted end-to-end application'} recorded; see the [tutorial catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/).\n")
    return "".join(lines)


def scenario_links() -> str:
    return (
        "- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) "
        "([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): "
        "delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/planning/roadmap/#reference-application-portfolio).\n"
        "- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) "
        "([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): "
        "candidate business goals and their existing related slices.\n"
        "- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) "
        "([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): "
        "cross-language tutorials, examples, and reference-application paths.\n"
    )


def content_links(directory: Path) -> str:
    lines = []
    relative = directory.relative_to(ROOT).as_posix()
    key = "go" if directory == ROOT else directory.name
    entry = {"key": key, "dir": "." if key == "go" else relative}
    for folder, label in (("Tutorial", "Scenario tutorials"), ("application", "Reference applications")):
        items = [item for item in _catalog_entries(ROOT, entry, folder) if folder == "application" or item[0] != folder]
        lines.extend([f"\n### {label}\n\n"])
        if items:
            for name, target, description in items:
                lines.append(
                    f"- [{name}](https://github.com/axisvela/praxo-core/tree/main/{target}): "
                    f"{description or 'See the README for scope and verification.'}\n"
                )
        elif folder == "application":
            lines.append("No accepted end-to-end reference application is recorded for this language yet.\n")
        else:
            lines.append("No language-specific tutorial slices are recorded yet.\n")
    lines.append(
        "\nApplication source is not end-to-end portfolio acceptance; read each README for scope and evidence.\n\n"
    )
    lines.append(scenario_links())
    return "".join(lines)
