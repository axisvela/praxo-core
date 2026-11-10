from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "spec" / "languages.md"
BLOCK_START = "## Registry and Coding-Agent Entry"
BLOCK_END = "## "

LANGUAGES = [
    {"dir": ".", "name": "Go", "package": "github.com/axisvela/praxo-core/v2", "registry": "Go module proxy / pkg.go.dev", "version": "v2.7.0", "tag": "v2.7.0", "install": "go get github.com/axisvela/praxo-core/v2@v2.7.0", "url": "https://pkg.go.dev/github.com/axisvela/praxo-core/v2", "status": "published", "tier": "Core (reference)", "docs": "https://axisvela.github.io/praxo-core/"},
    {"dir": "language/python", "name": "Python", "package": "praxo-core", "registry": "PyPI", "version": "0.4.1", "source_version": "0.4.1", "published_version": "0.4.1", "tag": "python/v0.4.1", "install": "pip install praxo-core==0.4.1", "source_install": "pip install praxo-core==0.4.1", "url": "https://pypi.org/project/praxo-core/0.4.1/", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/python/"},
    {"dir": "language/typescript", "name": "TypeScript", "package": "@axisvela/praxo-core", "registry": "npm", "version": "0.3.0", "source_version": "0.3.0", "published_version": "0.2.2", "tag": "typescript/v0.3.0", "install": "npm install @axisvela/praxo-core@0.2.2", "source_install": "npm install @axisvela/praxo-core@0.3.0", "url": "https://www.npmjs.com/package/@axisvela/praxo-core/v/0.2.2", "status": "source release prepared; registry 0.2.2 published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/typescript/"},
    {"dir": "language/java", "name": "Java", "package": "com.axisvela:praxo-core", "registry": "Maven Central", "version": "0.4.1", "tag": "java/v0.4.1", "install": "Maven: com.axisvela:praxo-core:0.4.1", "url": "https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.4.1/", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/java/"},
    {"dir": "language/rust", "name": "Rust", "package": "praxo-core", "registry": "crates.io", "version": "0.4.0", "source_version": "0.4.0", "published_version": "0.4.0", "tag": "rust/v0.4.0", "install": "cargo add praxo-core@0.4.0", "source_install": "cargo add praxo-core@0.4.0", "url": "https://crates.io/crates/praxo-core/0.4.0", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/rust/"},
    {"dir": "language/csharp", "name": "C#", "package": "Praxo.Core", "registry": "NuGet", "version": "0.4.0", "source_version": "0.4.0", "published_version": "0.3.0", "tag": "csharp/v0.4.0", "install": "dotnet add package Praxo.Core --version 0.3.0", "source_install": "dotnet add package Praxo.Core --version 0.4.0", "url": "https://www.nuget.org/packages/Praxo.Core/0.3.0", "status": "source release prepared; registry 0.3.0 published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/csharp/"},
    {"dir": "language/ruby", "name": "Ruby", "package": "praxo-core", "registry": "RubyGems", "version": "0.4.1", "tag": "ruby/v0.4.1", "install": "gem install praxo-core", "url": "https://rubygems.org/gems/praxo-core/versions/0.4.1", "status": "published; split source repository", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/ruby/"},
    {"dir": "language/php", "name": "PHP", "package": "axisvela/praxo-core", "registry": "Packagist", "version": "0.4.1", "source_version": "0.4.1", "published_version": "0.4.1", "tag": "php/v0.4.1", "install": "composer require axisvela/praxo-core", "url": "https://packagist.org/packages/axisvela/praxo-core", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/php/"},
    {"dir": "language/dart", "name": "Dart", "package": "praxo_core", "registry": "pub.dev", "version": "0.1.1", "tag": "dart/v0.1.1", "install": "dart pub add praxo_core", "url": "https://pub.dev/packages/praxo_core/versions/0.1.1", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/dart/"},
    {"dir": "language/elixir", "name": "Elixir", "package": "praxo_core", "registry": "Hex", "version": "0.5.0", "source_version": "0.5.0", "published_version": "0.4.1", "tag": "elixir/v0.5.0", "install": '{:praxo_core, "~> 0.4.1"}', "source_install": '{:praxo_core, "~> 0.5.0"}', "url": "https://hex.pm/packages/praxo_core", "status": "source release prepared; registry 0.4.1 published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/elixir/"},
    {"dir": "language/erlang", "name": "Erlang", "package": "praxo_core_erlang", "registry": "Hex", "version": "0.4.0", "tag": "erlang/v0.4.0", "install": '{deps, [{praxo_core_erlang, "0.4.0"}]}.', "url": "https://hex.pm/packages/praxo_core_erlang/0.4.0", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/erlang/"},
    {"dir": "language/lua", "name": "Lua", "package": "praxo-core", "registry": "LuaRocks", "version": "0.4.1-1", "source_version": "0.4.1-1", "published_version": "0.4.1-1", "tag": "lua/v0.4.1", "install": "luarocks install praxo-core", "url": "https://luarocks.org/modules/hanhhuiwen/praxo-core", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/lua/"},
    {"dir": "language/perl", "name": "Perl", "package": "Praxo::Core", "registry": "CPAN (MetaCPAN index)", "version": "0.1.1", "tag": "perl/v0.1.1", "install": "cpanm Praxo::Core", "url": "https://metacpan.org/dist/Praxo-Core", "status": "indexed on MetaCPAN (0.1.1); install smoke not recorded", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/perl/"},
    {"dir": "language/ocaml", "name": "OCaml", "package": "praxo-core", "registry": "opam (pending)", "version": "0.3.0", "tag": "ocaml/v0.3.0", "install": "opam install praxo-core", "url": "https://github.com/axisvela/praxo-core-ocaml", "status": "pending registry merge", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/ocaml/"},
    {"dir": "language/haskell", "name": "Haskell", "package": "praxo-core", "registry": "Hackage (pending)", "version": "0.2.0", "tag": "haskell/v0.2.0", "install": "cabal install praxo-core", "url": "https://github.com/axisvela/praxo-core/releases/tag/haskell%2Fv0.2.0", "status": "source release; Hackage upload pending", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/haskell/"},
    {"dir": "language/julia", "name": "Julia", "package": "PraxoCore", "registry": "Julia General (pending)", "version": "0.2.0", "tag": "julia/v0.2.0", "install": 'Pkg.add("PraxoCore")', "url": "https://github.com/axisvela/praxo-core-julia", "status": "pending registry merge", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/julia/"},
    {"dir": "language/swift", "name": "Swift", "package": "praxo-core-swift", "registry": "Swift Package Index", "version": "0.2.0", "tag": "swift/v0.2.0", "install": '.package(url: "https://github.com/axisvela/praxo-core-swift.git", from: "0.2.0")', "url": "https://swiftpackageindex.com/axisvela/praxo-core-swift", "status": "package list merged", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/swift/"},
    {"dir": "language/nim", "name": "Nim", "package": "praxo_core", "registry": "Nimble/nim-lang packages", "version": "0.1.1", "tag": "nim/v0.1.1", "install": "nimble install praxo_core", "url": "https://github.com/axisvela/praxo-core-nim", "status": "split repository; registry crawler pending", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/nim/"},
    {"dir": "language/v", "name": "V", "package": "praxo-core", "registry": "VPM (pending)", "version": "0.1.2", "tag": "v/v0.1.2", "install": "v install praxo-core", "url": "https://github.com/axisvela/praxo-core-v", "status": "split repository; VPM submission pending", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/v/"},
    {"dir": "language/d", "name": "D", "package": "praxo-core", "registry": "DUB", "version": "0.1.0", "tag": "d/v0.1.0", "install": "dub add praxo-core", "url": "https://code.dlang.org/packages/praxo-core", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/d/"},
    {"dir": "language/powershell", "name": "PowerShell", "package": "praxo-core-ps", "registry": "PowerShell Gallery", "version": "0.2.0", "tag": "powershell/v0.2.0", "install": "Install-Module praxo-core-ps", "url": "https://www.powershellgallery.com/packages/praxo-core-ps/0.2.0", "status": "published; shared C# runtime", "tier": "Core (.NET)", "docs": "https://axisvela.github.io/praxo-core/languages/powershell/"},
    {"dir": "language/r", "name": "R", "package": "praxocore", "registry": "r-universe", "version": "0.5.0", "tag": "r/v0.5.0", "install": 'install.packages("praxocore", repos = "https://axisvela.r-universe.dev")', "url": "https://axisvela.r-universe.dev/praxocore", "status": "r-universe only; CRAN not published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/r/"},
    {"dir": "language/matlab", "name": "MATLAB", "package": "PRAXO-CORE", "registry": "MATLAB File Exchange", "version": "0.2.1", "tag": "matlab/v0.2.1", "install": "File Exchange entry 185166", "url": "https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core", "status": "published; MATLAB runtime compatibility unverified", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/matlab/"},
    {"dir": "language/octave", "name": "GNU Octave", "package": "praxo-core", "registry": "Octave Packages", "version": "0.2.1", "tag": "octave/v0.2.1", "install": "pkg install -forge praxo-core", "url": "https://github.com/axisvela/praxo-core/releases/download/octave/v0.2.1/praxo-core-0.2.1.tar.gz", "status": "release tarball published; package index PR pending", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/octave/"},
    {"dir": "language/delphi", "name": "Delphi / Free Pascal", "package": "PRAXO-CORE", "registry": "OPM / GitHub release", "version": "0.2.1", "tag": "delphi/v0.2.1", "install": "OPM package or release archive", "url": "https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.2.1", "status": "source release; OPM submission pending", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/delphi/"},
    {"dir": "language/objc", "name": "Objective-C", "package": "praxo-core-objc", "registry": "Source", "version": "0.1.1", "tag": "objc/v0.1.1", "install": "See README/SETUP.md", "url": "", "status": "source-only", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/objc/"},
    {"dir": "language/c", "name": "C", "package": "praxo-core-c", "registry": "Source / CMake", "version": "0.6.0", "tag": "c/v0.6.0", "install": "CMake source build (see README)", "url": "", "status": "source-only", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/c/"},
    {"dir": "language/cpp", "name": "C++", "package": "praxo-core-cpp", "registry": "Source / CMake", "version": "0.4.0", "tag": "cpp/v0.4.0", "install": "CMake source build (see README)", "url": "", "status": "source-only", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/cpp/"},
    {"dir": "language/fortran", "name": "Fortran", "package": "praxo-core-fortran", "registry": "Source / CMake", "version": "0.6.0", "tag": "fortran/v0.6.0", "install": "Source build (see README)", "url": "", "status": "source-only", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/fortran/"},
    {"dir": "language/cobol", "name": "COBOL", "package": "praxo-core-cobol", "registry": "Source", "version": "0.4.0", "tag": "cobol/v0.4.0", "install": "Source build (see README)", "url": "", "status": "source-only", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/cobol/"},
    {"dir": "language/zig", "name": "Zig", "package": "praxo-core-zig", "registry": "Source", "version": "0.2.0", "tag": "zig/v0.2.0", "install": "Source build (see README)", "url": "", "status": "source-only", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/zig/"},
    {"dir": "language/matlab-octave-core", "name": "MATLAB/Octave shared core", "package": "shared implementation", "registry": "shared source", "version": "0.2.1", "tag": "matlab/v0.2.1 and octave/v0.2.1", "install": "Not a standalone package", "url": "", "status": "shared implementation; use MATLAB or Octave package", "tier": "Shared", "docs": "https://axisvela.github.io/praxo-core/languages/"},
]


for entry in LANGUAGES:
    entry.setdefault("source_version", entry["version"])
    entry.setdefault("published_version", entry["version"])
    entry.setdefault("source_install", entry["install"])

MANIFEST = ROOT / "language" / "registry-metadata.json"


def published_available(entry: dict) -> bool:
    return not (
        "source-only" in entry["status"]
        or "shared implementation" in entry["status"]
    )


def published_version_label(entry: dict) -> str:
    return f"`{entry['published_version']}`" if published_available(entry) else "not published"


def published_install_label(entry: dict) -> str:
    return f"`{entry['install']}`" if published_available(entry) else "not published"


def manifest_data() -> dict[str, dict[str, str]]:
    fields = (
        "dir", "package", "registry", "source_version", "published_version",
        "install", "source_install", "tag", "status", "docs", "url", "tier",
    )
    return {
        entry["name"]: {field: entry[field] for field in fields}
        for entry in LANGUAGES
    }


def load_spec_versions() -> dict[str, str]:
    values: dict[str, str] = {}
    for line in SPEC.read_text(encoding="utf-8").splitlines():
        match = re.match(r"\|\s*([^|]+?)\s*\|\s*[^|]+\|\s*released\s*\|\s*`([^`]+)`\s*\|", line)
        if match:
            values[match.group(1).strip().lower()] = match.group(2).strip()
    return values


def first_paragraph(readme: Path) -> str:
    if not readme.is_file():
        return "Shared implementation used by the MATLAB and Octave packages."
    text = readme.read_text(encoding="utf-8")
    lines = text.splitlines()
    paragraphs: list[str] = []
    current: list[str] = []
    for line in lines:
        if line.startswith("# "):
            continue
        if not line.strip():
            if current:
                paragraph = " ".join(part.strip() for part in current).strip()
                if paragraph and not paragraph.startswith("```"):
                    paragraphs.append(paragraph)
                    break
                current = []
            continue
        if line.startswith("## "):
            if current:
                break
            continue
        current.append(line)
    return paragraphs[0] if paragraphs else f"Native {readme.parent.name} implementation of the PRAXO-CORE contract."


def rel_link(target: str, entry_dir: Path) -> str:
    return Path(target).relative_to(ROOT).as_posix() if entry_dir == ROOT else "../../" + Path(target).relative_to(ROOT).as_posix()


def entry_paths(entry: dict) -> tuple[Path, Path, Path, Path]:
    directory = ROOT / entry["dir"]
    return (
        directory / "README.md",
        directory / "REGISTRY.md",
        directory / "llms.txt",
        directory / "llms.md",
    )


def block(entry: dict, directory: Path) -> str:
    base = "https://github.com/axisvela/praxo-core/blob/main"
    relative = Path(entry["dir"]).as_posix()
    prefix = base if relative == "." else f"{base}/{relative}"
    coding = f"{base}/docs/getting-started/coding-agents.md"
    registry = f"[{entry['registry']}]({entry['url']})" if entry["url"] else entry["registry"]
    if relative == ".":
        registry = "[Language Release Index](docs/languages/registry-status.md)"
    return (
        f"{BLOCK_START}\n\n"
        f"- Registry introduction: [REGISTRY.md]({prefix}/REGISTRY.md)\n"
        f"- Machine-readable entry: [llms.txt]({prefix}/llms.txt) and [llms.md]({prefix}/llms.md)\n"
        f"- Coding-agent contract: [docs/getting-started/coding-agents.md]({coding})\n"
        f"- Registry: {registry}\n"
    )


def insert_block(readme: Path, entry: dict) -> None:
    directory = readme.parent
    if not readme.is_file():
        readme.write_text(
            f"# PRAXO-CORE {entry['name']}\n\n"
            "Shared implementation used by the MATLAB and Octave packages. It is not a\n"
            "standalone package; use the MATLAB or Octave registry entry.\n\n"
            + block(entry, directory),
            encoding="utf-8",
        )
        return
    text = readme.read_text(encoding="utf-8")
    if BLOCK_START in text:
        pattern = re.compile(
            r"## Registry and Coding-Agent Entry\n.*?(?=\n## |\Z)",
            re.DOTALL,
        )
        text = pattern.sub(block(entry, directory).rstrip() + "\n", text, count=1)
        readme.write_text(text, encoding="utf-8")
        return
    marker = "\n## "
    index = text.find(marker)
    if index == -1:
        text = text.rstrip() + "\n\n" + block(entry, directory)
    else:
        text = text[:index] + "\n" + block(entry, directory) + text[index:]
    readme.write_text(text, encoding="utf-8")


def render_registry(entry: dict, directory: Path) -> str:
    summary = first_paragraph(directory / "README.md")
    registry = f"[{entry['registry']}]({entry['url']})" if entry["url"] else entry["registry"]
    published_version = published_version_label(entry)
    published_install = published_install_label(entry)
    return f"""# PRAXO-CORE {entry['name']} Registry Introduction

**Status:** {entry['status']}. Source version `{entry['source_version']}`, source
tag `{entry['tag']}`. Published registry version: {published_version}. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

{summary}

## Package

| Field | Value |
| --- | --- |
| Package | `{entry['package']}` |
| Registry | {registry} |
| Source version | `{entry['source_version']}` |
| Published registry version | {published_version} |
| Install (published) | {published_install} |
| Install (source/release prepared) | `{entry['source_install']}` |
| Source tag | `{entry['tag']}` |
| Tier | {entry['tier']} |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | {entry['docs']} |

## Coding-agent entry

- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract]({rel_link(ROOT / 'docs/getting-started/coding-agents.md', directory)}): explicit
  scope, final-argument authorization, denial tests, and verification commands.

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
"""


def render_llms(entry: dict, directory: Path, markdown: bool) -> str:
    registry = f"[{entry['registry']}]({entry['url']})" if entry["url"] else entry["registry"]
    coding = rel_link(ROOT / "docs/getting-started/coding-agents.md", directory)
    heading = "#"
    published_version = published_version_label(entry)
    published_install = published_install_label(entry)
    body = f"""{heading} PRAXO-CORE {entry['name']}

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `{entry['package']}`
- registry: {registry}
- source_version: `{entry['source_version']}`
- published_version: {published_version}
- install_published: {published_install}
- install_source: `{entry['source_install']}`
- source_tag: `{entry['tag']}`
- tier: {entry['tier']}
- contract: `SPEC_VERSION` `0.2.0`
- documentation: {entry['docs']}

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- Coding-agent contract: {coding}

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
"""
    return body if markdown else body.replace("## ", "# ")


def root_language_rows() -> list[tuple[str, str, str, str, str]]:
    rows: list[tuple[str, str, str, str, str]] = []
    for entry in LANGUAGES:
        if "shared implementation" in entry["status"]:
            continue
        registry = f"[{entry['registry']}]({entry['url']})" if entry["url"] else entry["registry"]
        rows.append(
            (
                entry["name"],
                f"`{entry['package']}`",
                registry,
                published_version_label(entry),
                entry["docs"],
            )
        )
    return rows


def render_root_registry() -> str:
    rows = "\n".join("| " + " | ".join(row) + " |" for row in root_language_rows())
    return f"""# PRAXO-CORE Registry Introduction

**Status:** multi-language framework. Go is the reference implementation; each
language implementation has its own package, documented scope, and evidence.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework with explicit policy
controls, checkpoints, and event tracing. It is not a Go-only framework.

## Languages

| Language | Package | Registry | Published version | Documentation |
| --- | --- | --- | --- | --- |
{rows}

Source releases, package-registry publication, conformance, and production
verification are separate claims. Check each language's registry page and
documentation before relying on a version or feature.

## Canonical source and dedicated repositories

- Canonical source: https://github.com/axisvela/praxo-core
- Language implementations: https://github.com/axisvela/praxo-core/tree/main/language
- Dedicated language repositories are listed in the
  [language repository index](docs/languages/repositories.md).

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from a
  package.
- Registry pages are release snapshots; the canonical documentation may be newer.
"""


def render_root_llms() -> str:
    lines = []
    for name, package, registry, published, docs in root_language_rows():
        lines.append(
            f"- {name}: {package} — {registry} — {published} — {docs}"
        )
    languages = "\n".join(lines)
    return f"""# PRAXO-CORE

> Multi-language governed agent execution kernel. Go is the reference
> implementation; Python, TypeScript, Java, Rust, C#, R, Ruby, PHP, Elixir, Lua,
> and other implementations ship independent packages. This file is a
> machine-readable entry point for coding tools; it does not guarantee discovery,
> installation, or adoption.

## Languages

{languages}

## Start

- README: https://github.com/axisvela/praxo-core/blob/main/README.md
- Quickstart: https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/quickstart.md
- Start Here: https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/index.md
- Coding-agent contract: https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md
- Language repository index: https://github.com/axisvela/praxo-core/blob/main/docs/languages/repositories.md
- When Not To Use: https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/when-not-to-use.md

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
"""


def write_entry(entry: dict) -> None:
    readme, registry, llms_txt, llms_md = entry_paths(entry)
    directory = readme.parent
    directory.mkdir(parents=True, exist_ok=True)
    insert_block(readme, entry)
    if entry["dir"] == ".":
        registry.write_text(render_root_registry(), encoding="utf-8")
        llms_md.write_text(render_root_llms(), encoding="utf-8")
        return
    registry.write_text(render_registry(entry, directory), encoding="utf-8")
    llms_txt.write_text(render_llms(entry, directory, markdown=False), encoding="utf-8")
    llms_md.write_text(render_llms(entry, directory, markdown=True), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    missing: list[str] = []
    for entry in LANGUAGES:
        readme, registry, llms_txt, llms_md = entry_paths(entry)
        if args.check:
            for path in (readme, registry, llms_txt, llms_md):
                if not path.is_file():
                    missing.append(str(path.relative_to(ROOT)))
            if readme.is_file() and BLOCK_START not in readme.read_text(encoding="utf-8"):
                missing.append(f"{readme.relative_to(ROOT)}: missing registry block")
            if entry["dir"] == ".":
                if registry.is_file() and registry.read_text(encoding="utf-8") != render_root_registry():
                    missing.append(f"{registry.relative_to(ROOT)}: stale multi-language registry entry")
                if llms_md.is_file() and llms_md.read_text(encoding="utf-8") != render_root_llms():
                    missing.append(f"{llms_md.relative_to(ROOT)}: stale multi-language llms entry")
        else:
            write_entry(entry)
    if args.check:
        if not MANIFEST.is_file():
            missing.append(str(MANIFEST.relative_to(ROOT)))
    else:
        MANIFEST.write_text(
            json.dumps(manifest_data(), indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    if missing:
        print("\n".join(missing))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
