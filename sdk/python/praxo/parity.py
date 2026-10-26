from __future__ import annotations

import importlib
from pathlib import Path


def check_parity(root: Path | None = None) -> list[str]:
    root = root or Path(__file__).resolve().parents[3]
    text = (root / "spec" / "parity.md").read_text(encoding="utf-8")
    statuses: dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("| `pkg/"):
            continue
        cells = [cell.strip() for cell in line.split("|")]
        if len(cells) < 7:
            continue
        statuses[cells[1].strip("`")] = cells[3]

    failures: list[str] = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("| `") or line.startswith("| `pkg/"):
            continue
        cells = [cell.strip() for cell in line.split("|")]
        if len(cells) < 7:
            continue
        go_symbol = cells[1].strip("`")
        python_symbol = cells[3].strip("`")
        if not python_symbol or "." not in python_symbol:
            continue
        prefix = go_symbol.rsplit(".", 1)[0]
        package = prefix if prefix.startswith("pkg/") else f"pkg/{prefix}"
        if statuses.get(package) != "parity":
            continue
        module_name, attribute = python_symbol.rsplit(".", 1)
        try:
            module = importlib.import_module(module_name)
        except ImportError as exc:
            failures.append(f"{python_symbol}: {exc}")
            continue
        if not hasattr(module, attribute):
            failures.append(f"{python_symbol}: missing")
    return failures
