import argparse
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]


def version():
    sdk = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    spec = (REPO / "spec/SPEC_VERSION").read_text(encoding="utf-8").strip()
    models = (ROOT / "src/praxo_models.erl").read_text(encoding="utf-8")
    sdk_match = re.search(r'sdk_version\(\)\s*->\s*<<"([^"]+)">>', models)
    spec_match = re.search(r'spec_version\(\)\s*->\s*<<"([^"]+)">>', models)
    if not sdk_match or sdk_match[1] != sdk:
        raise ValueError("Erlang SDK version does not match VERSION")
    if not spec_match or spec_match[1] != spec:
        raise ValueError("Erlang contract version does not match spec/SPEC_VERSION")
    return sdk, spec


def snapshot():
    sdk, spec = version()
    lines = ["# PRAXO-CORE Erlang Core API " + sdk, "# SPEC_VERSION " + spec, ""]
    for path in sorted((ROOT / "src").glob("*.erl")):
        text = path.read_text(encoding="utf-8")
        module = re.search(r"-module\((\w+)\)", text)[1]
        functions = set()
        for block in re.findall(r"-export\(\[(.*?)\]\)\.", text, re.DOTALL):
            for name, arity in re.findall(r"(\w+)\s*/\s*(\d+)", block):
                functions.add((name, int(arity)))
        if not functions:
            raise ValueError("missing exports: " + module)
        lines.append("## " + module)
        for name, arity in sorted(functions):
            lines.append(f"{module}.{name}/{arity}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def parity_errors():
    text = (REPO / "spec/parity/erlang.md").read_text(encoding="utf-8")
    sdk, spec = version()
    api = snapshot()
    errors = []
    if "- Tier: core" not in text.splitlines():
        errors.append("Erlang parity tier is not core")
    if "- SPEC_VERSION: " + spec not in text.splitlines():
        errors.append("contract version mismatch")
    if "`erlang/v" + sdk + "`" not in text:
        errors.append("parity release tag does not match VERSION")
    rows = 0
    for line in text.splitlines():
        if not line.startswith("| `"):
            continue
        cells = line.split("|")
        symbol = cells[2].strip(" `")
        if not re.fullmatch(r"\w+\.\w+/\d+", symbol):
            errors.append("invalid Erlang symbol: " + symbol)
        elif ("## " + symbol.split(".")[0]) not in api or symbol not in api:
            errors.append("missing Erlang export: " + symbol)
        rows += 1
    if rows == 0:
        errors.append("empty parity inventory")
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    sdk, _ = version()
    target = ROOT / "api" / f"{sdk}.txt"
    content = snapshot()
    errors = parity_errors()
    if errors:
        raise ValueError("\n".join(errors))
    if args.check:
        if not target.is_file() or target.read_text(encoding="utf-8") != content:
            print("Erlang API snapshot is missing or stale", file=sys.stderr)
            return 1
        print("Erlang API snapshot and parity are current")
    else:
        target.parent.mkdir(exist_ok=True)
        target.write_text(content, encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
