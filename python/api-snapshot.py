from __future__ import annotations

import argparse
import importlib
import inspect
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

import praxo

MODULES = [
    "praxo",
    "praxo.adapters",
    "praxo.adapters.openaicompat",
    "praxo.agent",
    "praxo.checkpoint",
    "praxo.context",
    "praxo.errors",
    "praxo.event",
    "praxo.jsonschema",
    "praxo.memory",
    "praxo.middleware",
    "praxo.middleware.base",
    "praxo.middleware.calllimit",
    "praxo.middleware.fallback",
    "praxo.middleware.pii",
    "praxo.middleware.structured",
    "praxo.middleware.toolselect",
    "praxo.model",
    "praxo.plugin",
    "praxo.policy",
    "praxo.stream",
    "praxo.tool",
    "praxo.toolcall",
]


def snapshot() -> str:
    lines = [f"# PRAXO-CORE Python API {praxo.__version__}", ""]
    for module_name in MODULES:
        module = importlib.import_module(module_name)
        names = getattr(module, "__all__", None)
        if names is None:
            names = [
                name
                for name in dir(module)
                if not name.startswith("_")
                and (
                    _defined_here(module, name)
                    or name.isupper()
                )
            ]
        entries = []
        for name in names:
            obj = getattr(module, name, None)
            if obj is None:
                continue
            if inspect.isfunction(obj):
                entries.append(f"{module_name}.{name}{_signature(obj)}")
            else:
                entries.append(f"{module_name}.{name}")
        lines.append(f"## {module_name}")
        lines.extend(sorted(entries))
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def _defined_here(module: object, name: str) -> bool:
    obj = getattr(module, name, None)
    if inspect.isclass(obj) or inspect.isfunction(obj):
        return getattr(obj, "__module__", "") == getattr(module, "__name__", "")
    return False


def _signature(obj: object) -> str:
    try:
        return str(inspect.signature(obj))
    except (TypeError, ValueError):
        return ""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = ROOT / "api" / f"{praxo.__version__}.txt"
    content = snapshot()
    if args.check:
        if not path.exists():
            print(f"missing snapshot: {path}")
            return 1
        if path.read_text(encoding="utf-8") != content:
            print(f"snapshot is stale: {path}")
            return 1
        print(f"snapshot is current: {path}")
        return 0
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
