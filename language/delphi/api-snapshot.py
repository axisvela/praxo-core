import argparse
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]


def interface_text(filename="praxo.pas"):
    text = (ROOT / filename).read_text(encoding="utf-8")
    match = re.search(r"\binterface\b(.*?)\bimplementation\b", text, re.DOTALL)
    if not match:
        raise ValueError("missing interface section")
    return match[1]


def snapshot():
    spec = (REPO / "spec/SPEC_VERSION").read_text(encoding="utf-8").strip()
    interface = interface_text()
    sdk = re.search(r"PraxoSdkVersion\s*=\s*'([^']+)'", interface)
    declared_spec = re.search(r"PraxoSpecVersion\s*=\s*'([^']+)'", interface)
    if not sdk or not declared_spec or declared_spec[1] != spec:
        raise ValueError("Pascal SDK or contract version does not match specification")
    lines = ["# PRAXO-CORE Delphi/Free Pascal Wire API " + sdk[1],
             "# SPEC_VERSION " + spec, ""]
    for raw in (interface + "\n" + interface_text("praxo_agent.pas")).splitlines():
        line = raw.strip()
        match = re.match(r"^(function|procedure)\s+(\w+)", line, re.IGNORECASE)
        if match:
            lines.append(line.rstrip(";") + ";")
    if len(lines) <= 3:
        raise ValueError("no public Pascal functions found")
    return "\n".join(lines) + "\n"


def parity_errors():
    text = (REPO / "spec/parity/delphi.md").read_text(encoding="utf-8")
    interface = interface_text() + "\n" + interface_text("praxo_agent.pas")
    spec = (REPO / "spec/SPEC_VERSION").read_text(encoding="utf-8").strip()
    errors = []
    if "- SPEC_VERSION: " + spec not in text.splitlines():
        errors.append("contract version mismatch")
    rows = 0
    for line in text.splitlines():
        if not line.startswith("| `"):
            continue
        cells = line.split("|")
        symbol = cells[2].strip(" `")
        if not re.search(r"^(function|procedure)\s+" + re.escape(symbol) + r"\b", interface, re.IGNORECASE | re.MULTILINE):
            errors.append("missing parity function: " + symbol)
        rows += 1
    if rows == 0:
        errors.append("empty parity inventory")
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    target = ROOT / "api/unreleased.txt"
    content = snapshot()
    errors = parity_errors()
    if errors:
        raise ValueError("\n".join(errors))
    if args.check:
        if not target.is_file() or target.read_text(encoding="utf-8") != content:
            print("Delphi API snapshot is missing or stale", file=sys.stderr)
            return 1
        print("Delphi API snapshot and parity are current")
    else:
        target.parent.mkdir(exist_ok=True)
        target.write_text(content, encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
