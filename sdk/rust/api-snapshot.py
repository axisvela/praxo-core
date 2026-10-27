import argparse
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parent
KINDS = {"struct", "enum", "trait", "type", "fn", "constant", "static", "union", "macro"}


class Rustdoc(HTMLParser):
    def __init__(self):
        super().__init__()
        self.main = False
        self.found_main = False
        self.group = ""
        self.stack = []
        self.links = []
        self.declaration = []
        self.implementations = []
        self.symbols = set()
        self.capture = None
        self.parts = []
        self.ignored = 0

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        self.stack.append((tag, attrs))
        if attrs.get("id") == "main-content":
            self.main = True
            self.found_main = True
        if not self.main:
            return
        if tag == "h2":
            self.group = attrs.get("id", "")
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])
        classes = attrs.get("class", "").split()
        if tag == "pre" and "item-decl" in classes and not self.group:
            self.capture = (tag, "item")
            self.parts = []
        elif "code-header" in classes:
            if tag == "h3" and self.group in ("implementations", "trait-implementations"):
                self.capture = (tag, "impl")
                self.parts = []
            elif tag == "h4" and self.group == "implementations":
                self.capture = (tag, "method")
                self.parts = []
                for _, parent in reversed(self.stack):
                    identifier = parent.get("id", "")
                    if identifier.startswith(("method.", "associatedconstant.", "associatedtype.")):
                        self.symbols.add(identifier.partition(".")[2])
                        break
            elif tag == "h4" and self.group == "trait-implementations":
                if any(parent.get("class", "").startswith(("associatedtype", "associatedconstant")) for _, parent in self.stack):
                    self.capture = (tag, "associated")
                    self.parts = []
        if self.capture and tag == "summary":
            self.ignored += 1
        if self.capture and tag in ("div", "br"):
            self.parts.append(" ")
        if tag in ("br", "hr", "img", "input", "meta", "link", "wbr"):
            self.stack.pop()

    def handle_data(self, data):
        if self.capture and not self.ignored:
            self.parts.append(data)

    def handle_endtag(self, tag):
        if tag == "summary" and self.ignored:
            self.ignored -= 1
        if self.capture and tag == self.capture[0]:
            kind = self.capture[1]
            text = " ".join(line.strip() for line in "".join(self.parts).splitlines() if not line.strip().startswith("//"))
            text = re.sub(r"\s+", " ", text).strip()
            if kind == "item":
                self.declaration.append(text)
            elif "StructuralPartialEq" not in text:
                self.implementations.append(text if kind == "impl" else kind + " " + text)
            self.capture = None
        for index in range(len(self.stack) - 1, -1, -1):
            if self.stack[index][0] == tag:
                if any(attrs.get("id") == "main-content" for _, attrs in self.stack[index:]):
                    self.main = False
                del self.stack[index:]
                break


def collect_api(directory, crate):
    directory = directory.resolve()
    pending = [directory / "index.html"]
    visited = set()
    declarations = {}
    symbols = set()
    while pending:
        path = pending.pop()
        if path in visited:
            continue
        visited.add(path)
        parser = Rustdoc()
        parser.feed(path.read_text(encoding="utf-8"))
        if not parser.found_main:
            raise ValueError("rustdoc page lacks public item content: " + str(path))
        relative = path.relative_to(directory)
        module = "::".join([crate, *relative.parts[:-1]])
        if path.name == "index.html":
            declarations["module " + module] = []
            symbols.add(module)
            for link in parser.links:
                parts = urlsplit(link)
                if parts.scheme or parts.netloc or not parts.path.endswith(".html"):
                    continue
                target = (path.parent / unquote(parts.path)).resolve()
                if not target.is_relative_to(directory):
                    continue
                if target.name != "index.html" and target.name.partition(".")[0] not in KINDS:
                    continue
                if not target.is_file():
                    raise ValueError("missing public rustdoc item: " + str(target))
                pending.append(target)
        else:
            kind, _, item = path.name.removesuffix(".html").partition(".")
            name = module + "::" + item
            if len(parser.declaration) != 1 or not parser.declaration[0]:
                raise ValueError("missing or ambiguous public declaration: " + name)
            declarations[kind + " " + name] = parser.declaration + sorted(set(parser.implementations))
            symbols.add(name)
            symbols.update(name + "::" + method for method in parser.symbols)
    return declarations, symbols


def snapshot(declarations, version, spec):
    lines = ["# PRAXO-CORE Rust API " + version, "# SPEC_VERSION " + spec, ""]
    for name, signatures in sorted(declarations.items()):
        lines.extend(["## " + name, *signatures, ""])
    return "\n".join(lines)


def parity_errors(symbols, text, spec):
    errors = []
    if not re.search(r"^- SPEC_VERSION:\s*" + re.escape(spec) + r"\s*$", text, re.MULTILINE):
        errors.append("Rust parity contract version does not match specification")
    rows = 0
    for line in text.splitlines():
        if not line.startswith("| `"):
            continue
        cells = [cell.strip(" `") for cell in line.split("|")]
        if cells[3] not in ("parity", "partial"):
            continue
        name = "praxo_core::" + cells[2]
        if name not in symbols:
            errors.append("missing Rust parity symbol: " + name)
        rows += 1
    if rows == 0:
        errors.append("Rust parity inventory has no implemented symbols")
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    metadata = json.loads(subprocess.check_output(["cargo", "metadata", "--locked", "--no-deps", "--format-version", "1"], cwd=ROOT))
    package = next(item for item in metadata["packages"] if Path(item["manifest_path"]).resolve() == ROOT / "Cargo.toml")
    crate = next(target["name"] for target in package["targets"] if "lib" in target["kind"])
    spec = (ROOT.parents[1] / "spec/SPEC_VERSION").read_text(encoding="utf-8").strip()
    library = (ROOT / "src/lib.rs").read_text(encoding="utf-8")
    for name, value in (("SDK_VERSION", package["version"]), ("SPEC_VERSION", spec)):
        if not re.search(r"pub const " + name + r': &str = "' + re.escape(value) + r'";', library):
            raise ValueError(name + " does not match package/spec version")
    subprocess.run(["cargo", "doc", "--locked", "--no-deps", "--lib"], cwd=ROOT, check=True)
    declarations, symbols = collect_api(Path(metadata["target_directory"]) / "doc" / crate, crate)
    errors = parity_errors(symbols, (ROOT.parents[1] / "spec/parity/rust.md").read_text(encoding="utf-8"), spec)
    if errors:
        raise ValueError("\n".join(errors))
    content = snapshot(declarations, package["version"], spec)
    target = ROOT / "api" / (package["version"] + ".txt")
    if args.check:
        if not target.is_file() or target.read_text(encoding="utf-8") != content:
            print("Rust API snapshot is missing or stale", file=sys.stderr)
            return 1
        print("Rust public API snapshot and parity symbols are current")
    else:
        target.parent.mkdir(exist_ok=True)
        target.write_text(content, encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
