from __future__ import annotations

import argparse
import dataclasses
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


def _signature(obj: object) -> str:
    try:
        return str(inspect.signature(obj))
    except (TypeError, ValueError):
        return ""


def _defined_here(module: object, name: str) -> bool:
    obj = getattr(module, name, None)
    if inspect.isclass(obj) or inspect.isfunction(obj):
        return getattr(obj, "__module__", "") == getattr(module, "__name__", "")
    return False


def _default(value: object) -> str:
    if value is dataclasses.MISSING:
        return ""
    if value is inspect.Parameter.empty:
        return ""
    if isinstance(value, (str, int, float, bool, type(None), tuple)):
        return f" = {value!r}"
    return " = <default>"


def _field_lines(cls: type) -> list[str]:
    lines: list[str] = []
    if dataclasses.is_dataclass(cls):
        for field in dataclasses.fields(cls):
            annotation = field.type
            if not isinstance(annotation, str):
                annotation = getattr(annotation, "__name__", str(annotation))
            default = "" if field.default is dataclasses.MISSING else _default(field.default)
            if field.default_factory is not dataclasses.MISSING:
                default = " = <factory>"
            lines.append(f"field {field.name}: {annotation}{default}")
        return lines
    annotations = cls.__dict__.get("__annotations__", {})
    for name, annotation in annotations.items():
        if name.startswith("_"):
            continue
        if not isinstance(annotation, str):
            annotation = getattr(annotation, "__name__", str(annotation))
        lines.append(f"field {name}: {annotation}{_default(cls.__dict__.get(name))}")
    return lines


def _strip_self(signature: str) -> str:
    if signature.startswith("(self"):
        rest = signature[5:]
        if rest.startswith(", "):
            return "(" + rest[2:]
        if rest.startswith(")"):
            return "()" + rest[1:]
    return signature


def _member_lines(cls: type, skip: set[str]) -> list[str]:
    lines: list[str] = []
    for name, member in cls.__dict__.items():
        if name.startswith("_") or name in skip:
            continue
        if isinstance(member, staticmethod):
            lines.append(f"staticmethod {name}{_signature(member.__func__)}")
            continue
        if isinstance(member, classmethod):
            signature = _signature(member.__func__)
            if signature.startswith("(cls"):
                signature = "(" + signature[4:].lstrip(", ")
            lines.append(f"classmethod {name}{signature}")
            continue
        if isinstance(member, property):
            result = ""
            if member.fget is not None:
                result = _signature(member.fget)
                if " -> " in result:
                    result = " -> " + result.rsplit(" -> ", 1)[1]
                else:
                    result = ""
            lines.append(f"property {name}{result}")
            continue
        if inspect.isfunction(member):
            lines.append(f"method {name}{_strip_self(_signature(member))}")
            continue
        if not callable(member):
            lines.append(f"attribute {name}: {type(member).__name__}{_default(member)}")
    return lines


def class_lines(cls: type, name: str | None = None) -> list[str]:
    label = name or f"{cls.__module__}.{cls.__qualname__}"
    lines = [f"## {label}", f"class {cls.__name__}"]
    bases = [base.__name__ for base in cls.__bases__ if base is not object]
    if bases:
        lines.append(f"bases: {', '.join(bases)}")
    fields = set()
    if dataclasses.is_dataclass(cls):
        fields = {field.name for field in dataclasses.fields(cls)}
    else:
        fields = set(cls.__dict__.get("__annotations__", {}))
    lines.append(f"constructor{_signature(cls)}")
    lines.extend(_field_lines(cls))
    lines.extend(_member_lines(cls, fields))
    return lines


def function_lines(function: object, name: str | None = None) -> list[str]:
    label = name or getattr(function, "__qualname__", type(function).__name__)
    return [f"## {label}", f"function {label}{_signature(function)}"]


def _entries(module: object) -> list[str]:
    names = getattr(module, "__all__", None)
    if names is None:
        names = [
            name
            for name in dir(module)
            if not name.startswith("_")
            and (_defined_here(module, name) or name.isupper())
        ]
    lines: list[str] = []
    for name in sorted(names):
        obj = getattr(module, name, None)
        if obj is None:
            continue
        if inspect.isclass(obj):
            lines.extend(class_lines(obj, name))
        elif inspect.isfunction(obj):
            lines.extend(function_lines(obj, name))
        elif not callable(obj) and isinstance(obj, (str, int, float, bool, tuple)):
            lines.append(f"## {name}")
            lines.append(f"constant {name}: {type(obj).__name__} = {obj!r}")
        lines.append("")
    return lines


def snapshot() -> str:
    lines = [
        f"# PRAXO-CORE Python API Signatures {praxo.__version__}",
        f"# SPEC_VERSION {praxo.SPEC_VERSION}",
        "# Format 1: public classes, fields, methods, functions, and constants",
        "",
    ]
    for module_name in MODULES:
        module = importlib.import_module(module_name)
        lines.append(f"# module {module_name}")
        lines.extend(_entries(module))
    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = ROOT / "api" / f"{praxo.__version__}.signatures.txt"
    content = snapshot()
    if args.check:
        if not path.exists():
            print(f"missing signature snapshot: {path}")
            return 1
        if path.read_text(encoding="utf-8") != content:
            print(f"signature snapshot is stale: {path}")
            return 1
        print(f"signature snapshot is current: {path}")
        return 0
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
