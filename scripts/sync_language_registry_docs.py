from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from mirror_readme import _catalog_entries

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "spec" / "languages.md"
BLOCK_START = "## Registry and Coding-Agent Entry"
BLOCK_END = "## "
COMMUNITY_LINKS = (
    ("X", "https://x.com/axisvela"),
    ("Weibo", "https://weibo.com/u/1936025761"),
    ("LinkedIn", "https://www.linkedin.com/company/axisvela/"),
    ("Facebook", "https://www.facebook.com/profile.php?id=61596905732406"),
    ("YouTube", "https://www.youtube.com/@axisvela"),
    ("Discord", "https://discord.com/channels/1575163993767809064/1575164343148875977"),
    ("GitHub Discussions", "https://github.com/axisvela/praxo-core/discussions"),
    ("GitHub Issues", "https://github.com/axisvela/praxo-core/issues"),
    ("Documentation", "https://axisvela.github.io/praxo-core/"),
    ("Architect", "https://axisvela.architect.pub"),
)


def community_section() -> str:
    lines = ["## Community", ""]
    for name, link in COMMUNITY_LINKS:
        lines.append(f"- {name}: <{link}>")
    return "\n".join(lines) + "\n\n"


def community_entry() -> str:
    links = " · ".join(f"[{name}]({link})" for name, link in COMMUNITY_LINKS)
    return f"- Community: {links}\n"

LANGUAGES = [
    {"dir": ".", "name": "Go", "package": "github.com/axisvela/praxo-core/v2", "registry": "Go module proxy / pkg.go.dev", "version": "v2.11.0", "source_version": "v2.11.0", "published_version": "v2.11.0", "tag": "v2.11.0", "install": "go get github.com/axisvela/praxo-core/v2@v2.11.0", "url": "https://pkg.go.dev/github.com/axisvela/praxo-core/v2", "status": "published", "tier": "Core (reference)", "docs": "https://axisvela.github.io/praxo-core/"},
    {"dir": "language/python", "name": "Python", "package": "praxo-core", "registry": "PyPI", "version": "0.11.0", "source_version": "0.11.0", "published_version": "0.11.0", "tag": "python/v0.11.0", "install": "pip install praxo-core==0.11.0", "source_install": "pip install ./language/python", "url": "https://pypi.org/project/praxo-core/0.11.0/", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/python/"},
    {"dir": "language/typescript", "name": "TypeScript", "package": "@axisvela/praxo-core", "registry": "npm", "version": "0.10.0", "source_version": "0.10.0", "published_version": "0.10.0", "tag": "typescript/v0.10.0", "install": "npm install @axisvela/praxo-core@0.10.0", "source_install": "npm install ./language/typescript", "url": "https://www.npmjs.com/package/@axisvela/praxo-core/v/0.10.0", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/typescript/"},
    {"dir": "language/java", "name": "Java", "package": "com.axisvela:praxo-core", "registry": "Maven Central", "version": "0.12.0", "source_version": "0.12.0", "published_version": "0.12.0", "tag": "java/v0.12.0", "install": "Maven: com.axisvela:praxo-core:0.12.0", "source_install": "Maven source build (see README)", "url": "https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.12.0/", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/java/"},
    {"dir": "language/rust", "name": "Rust", "package": "praxo-core", "registry": "crates.io", "version": "0.11.0", "source_version": "0.11.0", "published_version": "0.11.0", "tag": "rust/v0.11.0", "install": "cargo add praxo-core@0.11.0", "source_install": "cargo add --path language/rust", "url": "https://crates.io/crates/praxo-core/0.11.0", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/rust/"},
    {"dir": "language/csharp", "name": "C#", "package": "Praxo.Core", "registry": "NuGet", "version": "0.11.0", "source_version": "0.11.0", "published_version": "0.11.0", "tag": "csharp/v0.11.0", "install": "dotnet add package Praxo.Core --version 0.11.0", "source_install": "ProjectReference to language/csharp/Praxo.Core", "url": "https://www.nuget.org/packages/Praxo.Core/0.11.0", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/csharp/"},
    {"dir": "language/ruby", "name": "Ruby", "package": "praxo-core", "registry": "RubyGems", "version": "0.10.0", "source_version": "0.10.0", "published_version": "0.10.0", "source_install": "From language/ruby: gem build praxo-core.gemspec, then gem install ./praxo-core-0.10.0.gem", "tag": "ruby/v0.10.0", "install": "gem install praxo-core -v 0.10.0", "url": "https://rubygems.org/gems/praxo-core/versions/0.10.0", "status": "published; split source repository", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/ruby/"},
    {"dir": "language/php", "name": "PHP", "package": "axisvela/praxo-core", "registry": "Packagist", "version": "0.10.0", "source_version": "0.10.0", "published_version": "0.10.0", "source_install": "Composer path repository: language/php", "tag": "php/v0.10.0", "install": "composer require axisvela/praxo-core:0.10.0", "url": "https://packagist.org/packages/axisvela/praxo-core", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/php/"},
    {"dir": "language/dart", "name": "Dart", "package": "praxo_core", "registry": "pub.dev", "version": "0.8.0", "source_version": "0.8.0", "published_version": "0.8.0", "source_install": "dart pub add praxo_core --path language/dart", "tag": "dart/v0.8.0", "install": "dart pub add praxo_core:0.8.0", "url": "https://pub.dev/packages/praxo_core/versions/0.8.0", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/dart/"},
    {"dir": "language/elixir", "name": "Elixir", "package": "praxo_core", "registry": "Hex", "version": "0.11.0", "source_version": "0.11.0", "published_version": "0.11.0", "tag": "elixir/v0.11.0", "install": '{:praxo_core, "~> 0.11.0"}', "source_install": '{:praxo_core, path: "language/elixir"}', "url": "https://hex.pm/packages/praxo_core/0.11.0", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/elixir/"},
    {"dir": "language/erlang", "name": "Erlang", "package": "praxo_core_erlang", "registry": "Hex", "version": "0.10.0", "source_version": "0.10.0", "published_version": "0.10.0", "source_install": '{praxo_core, {path, "language/erlang"}}', "tag": "erlang/v0.10.0", "install": '{praxo_core, "0.10.0", {pkg, praxo_core_erlang}}', "url": "https://hex.pm/packages/praxo_core_erlang/0.10.0", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/erlang/"},
    {"dir": "language/lua", "name": "Lua", "package": "praxo-core", "registry": "LuaRocks", "version": "0.9.0-1", "source_version": "0.9.0-1", "published_version": "0.9.0-1", "source_install": "luarocks make language/lua/praxo-core-0.9.0-1.rockspec", "tag": "lua/v0.9.0", "install": "luarocks install praxo-core 0.9.0-1", "url": "https://luarocks.org/modules/hanhhuiwen/praxo-core", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/lua/"},
    {"dir": "language/perl", "name": "Perl", "package": "Praxo::Core", "registry": "CPAN (MetaCPAN index)", "version": "0.8.0", "source_version": "0.8.0", "published_version": "0.8.0", "source_install": "cpanm ./language/perl", "tag": "perl/v0.8.0", "install": "cpanm Praxo::Core@0.8.0", "url": "https://metacpan.org/dist/Praxo-Core", "status": "published on CPAN; README.pod indexed", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/perl/"},
    {"dir": "language/ocaml", "name": "OCaml", "package": "praxo-core", "registry": "opam (pending)", "version": "0.11.1", "source_version": "0.11.1", "published_version": "", "source_install": "Source checkout: language/ocaml (see README build instructions)", "tag": "ocaml/v0.11.1", "install": "", "url": "https://github.com/axisvela/praxo-core-ocaml", "status": "not published; replacement submission pending", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/ocaml/"},
    {"dir": "language/haskell", "name": "Haskell", "package": "praxo-core", "registry": "Hackage", "version": "0.9.0", "source_version": "0.9.0", "published_version": "0.9.0", "source_install": "cabal build --project-dir=language/haskell", "tag": "haskell/v0.9.0", "install": "cabal install --lib praxo-core-0.9.0", "url": "https://hackage.haskell.org/package/praxo-core-0.9.0", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/haskell/"},
    {"dir": "language/julia", "name": "Julia", "package": "PraxoCore", "registry": "Julia General (pending)", "version": "0.9.0", "source_version": "0.9.0", "published_version": "", "source_install": 'Pkg.develop(path="language/julia")', "tag": "julia/v0.9.0", "install": "", "url": "https://github.com/axisvela/PraxoCore.jl", "status": "not published; General registry merge pending", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/julia/"},
    {"dir": "language/swift", "name": "Swift", "package": "praxo-core-swift", "registry": "Swift Package Index", "version": "0.7.2", "source_version": "0.9.0", "published_version": "0.7.2", "source_install": '.package(path: "language/swift")', "tag": "swift/v0.9.0", "install": '.package(url: "https://github.com/axisvela/praxo-core-swift.git", exact: "0.7.2")', "url": "https://swiftpackageindex.com/axisvela/praxo-core-swift", "status": "published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/swift/"},
    {"dir": "language/nim", "name": "Nim", "package": "praxo_core", "registry": "Nimble/nim-lang packages (unverified)", "version": "0.8.0", "source_version": "0.8.0", "published_version": "", "source_install": "Source checkout: language/nim (see README build instructions)", "tag": "nim/v0.8.0", "install": "", "url": "https://github.com/axisvela/praxo-core-nim", "status": "split repository v0.8.0 tagged; Nimble/nimpkgs re-crawl pending", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/nim/"},
    {"dir": "language/v", "name": "V", "package": "praxo-core", "registry": "VPM (pending)", "version": "0.8.0", "source_version": "0.8.0", "published_version": "", "source_install": "Source checkout: language/v (see README build instructions)", "tag": "v/v0.8.0", "install": "", "url": "https://github.com/axisvela/praxo-core-v", "status": "split repository 0.8.0 tagged; VPM submission pending", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/v/"},
    {"dir": "language/d", "name": "D", "package": "praxo-core", "registry": "DUB", "version": "0.8.0", "source_version": "0.8.0", "published_version": "0.8.0", "source_install": "dub build --root=language/d", "tag": "d/v0.8.0", "install": "dub add praxo-core@0.8.0", "url": "https://code.dlang.org/packages/praxo-core", "status": "published; split source repository", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/d/"},
    {"dir": "language/powershell", "name": "PowerShell", "package": "praxo-core-ps", "registry": "PowerShell Gallery", "version": "0.8.1", "source_version": "0.9.0", "published_version": "0.8.1", "source_install": "Install-Module praxo-core-ps", "tag": "powershell/v0.9.0", "install": "Install-Module praxo-core-ps", "url": "https://www.powershellgallery.com/packages/praxo-core-ps/0.8.1", "status": "published; shared C# runtime", "tier": "Core (.NET)", "docs": "https://axisvela.github.io/praxo-core/languages/powershell/"},
    {"dir": "language/r", "name": "R", "package": "praxocore", "registry": "r-universe", "version": "0.12.0", "source_version": "0.12.0", "published_version": "0.12.0", "tag": "r/v0.12.0", "install": 'install.packages("praxocore", repos = "https://axisvela.r-universe.dev")', "source_install": "R CMD INSTALL language/r", "url": "https://axisvela.r-universe.dev/praxocore", "status": "published on r-universe; CRAN not published", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/r/"},
    {"dir": "language/matlab", "name": "MATLAB", "package": "PRAXO-CORE", "registry": "MATLAB File Exchange", "version": "0.9.1", "source_version": "0.9.0", "published_version": "0.9.1", "source_install": "Source checkout: language/matlab and language/matlab-octave-core (see README)", "tag": "matlab/v0.9.0", "install": "File Exchange entry 185166 (0.9.1)", "url": "https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core", "status": "published; MATLAB runtime unverified", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/matlab/"},
    {"dir": "language/octave", "name": "GNU Octave", "package": "praxo-core", "registry": "GitHub release (Octave package index pending)", "version": "0.7.0", "source_version": "0.9.0", "published_version": "0.7.0", "source_install": "Source checkout: language/octave and language/matlab-octave-core (see README)", "tag": "octave/v0.9.0", "install": "pkg install https://github.com/axisvela/praxo-core/releases/download/octave/v0.7.0/praxo-core-0.7.0.tar.gz", "url": "https://github.com/axisvela/praxo-core/releases/download/octave/v0.7.0/praxo-core-0.7.0.tar.gz", "status": "published release tarball 0.7.0; package index PR pending", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/octave/"},
    {"dir": "language/delphi", "name": "Delphi / Free Pascal", "package": "PRAXO-CORE", "registry": "GitHub release (OPM listing unverified)", "version": "0.7.0", "source_version": "0.9.0", "published_version": "0.7.0", "source_install": "Source checkout: language/delphi (see README)", "tag": "delphi/v0.9.0", "install": "Download 0.7.0 assets from https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.7.0", "url": "https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.7.0", "status": "published GitHub release assets 0.7.0; OPM listing unverified", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/delphi/"},
    {"dir": "language/objc", "name": "Objective-C", "package": "praxo-core-objc", "registry": "Source", "version": "0.8.0", "source_version": "0.8.0", "published_version": "", "source_install": "See README/SETUP.md", "tag": "objc/v0.8.0", "install": "", "url": "", "status": "source-only", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/objc/"},
    {"dir": "language/c", "name": "C", "package": "praxo-core-c", "registry": "Source / CMake", "version": "0.14.0", "source_version": "0.14.0", "published_version": "", "source_install": "CMake source build (see README)", "tag": "c/v0.14.0", "install": "", "url": "", "status": "source-only", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/c/"},
    {"dir": "language/cpp", "name": "C++", "package": "praxo-core-cpp", "registry": "Source / CMake", "version": "0.10.0", "source_version": "0.10.0", "published_version": "", "source_install": "CMake source build (see README)", "tag": "cpp/v0.10.0", "install": "", "url": "", "status": "source-only", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/cpp/"},
    {"dir": "language/fortran", "name": "Fortran", "package": "praxo-core-fortran", "registry": "Source / CMake", "version": "0.12.0", "source_version": "0.12.0", "published_version": "", "source_install": "Source build (see README)", "tag": "fortran/v0.12.0", "install": "", "url": "", "status": "source-only", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/fortran/"},
    {"dir": "language/cobol", "name": "COBOL", "package": "praxo-core-cobol", "registry": "Source", "version": "0.9.0", "source_version": "0.9.0", "published_version": "", "source_install": "Source build (see README)", "tag": "cobol/v0.9.0", "install": "", "url": "", "status": "source-only", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/cobol/"},
    {"dir": "language/zig", "name": "Zig", "package": "praxo-core-zig", "registry": "Source", "version": "0.9.0", "source_version": "0.9.0", "published_version": "", "source_install": "Source build (see README)", "tag": "zig/v0.9.0", "install": "", "url": "", "status": "source-only", "tier": "Core", "docs": "https://axisvela.github.io/praxo-core/languages/zig/"},
    {"dir": "language/matlab-octave-core", "name": "MATLAB/Octave shared core", "package": "shared implementation", "registry": "shared source", "version": "0.9.0", "source_version": "0.9.0", "published_version": "", "source_install": "Not a standalone package", "tag": "matlab/v0.9.0 and octave/v0.9.0", "install": "", "url": "", "status": "shared implementation; use MATLAB or Octave package", "tier": "Shared", "docs": "https://axisvela.github.io/praxo-core/languages/"},
]


for entry in LANGUAGES:
    entry.setdefault("source_version", entry["version"])
    entry.setdefault("source_install", entry["install"])
    entry.setdefault("published_version", "")

MANIFEST = ROOT / "language" / "registry-metadata.json"
ADAPTER_STATUS = ROOT / "docs" / "languages" / "adapter-status.md"
CAPABILITY_SECTIONS = (
    ("Model (OpenAI-Compatible)", "OpenAI-compatible model"),
    ("Model (Anthropic Native)", "Anthropic model"),
    ("Model (Gemini Native)", "Gemini model"),
    ("MCP", "MCP client"),
    ("Harmovela", "Harmovela sink"),
    ("OpenTelemetry", "OpenTelemetry sink"),
    ("Delegation", "Subagent delegation"),
    ("Retriever", "Retriever"),
)
_CAPABILITIES: dict[str, dict[str, tuple[str, str]]] | None = None


def adapter_capabilities() -> dict[str, dict[str, tuple[str, str]]]:
    global _CAPABILITIES
    if _CAPABILITIES is not None:
        return _CAPABILITIES
    text = ADAPTER_STATUS.read_text(encoding="utf-8")
    result: dict[str, dict[str, tuple[str, str]]] = {}
    for heading, label in CAPABILITY_SECTIONS:
        match = re.search(
            r"## " + re.escape(heading) + r"\n(.*?)(?=\n## |\Z)", text, re.DOTALL
        )
        if not match:
            raise ValueError("adapter-status.md: missing section " + heading)
        rows: dict[str, tuple[str, str]] = {}
        for line in match.group(1).splitlines():
            if not line.startswith("| ") or line.startswith("| Language") or line.startswith("| ---"):
                continue
            cells = [cell.strip() for cell in line.strip("|").split("|")]
            language = cells[0]
            if language.startswith("All other") or language.startswith("Other"):
                continue
            if language in rows:
                raise ValueError(
                    "adapter-status.md: duplicate " + label + " row for " + language
                )
            rows[language] = (cells[1], " | ".join(cells[2:]).strip())
        result[label] = rows
    _CAPABILITIES = result
    return result


def capability_rows(entry: dict) -> list[tuple[str, str, str]] | None:
    if entry["name"] == "MATLAB/Octave shared core":
        return None
    capabilities = adapter_capabilities()
    rows: list[tuple[str, str, str]] = []
    for _, label in CAPABILITY_SECTIONS:
        status, notes = capabilities[label].get(entry["name"], ("not implemented", ""))
        rows.append((label, status, notes))
    return rows


def capabilities_registry(entry: dict) -> str:
    rows = capability_rows(entry)
    if rows is None:
        return ""
    lines = ["## Capabilities and Status", "", "| Adapter | Status | Detail |", "| --- | --- | --- |"]
    for label, status, notes in rows:
        lines.append(f"| {label} | {status} | {notes} |")
    return "\n".join(lines) + "\n\n"


def capabilities_llms(entry: dict) -> str:
    rows = capability_rows(entry)
    if rows is None:
        return ""
    lines = ["## Capabilities and Status", ""]
    for label, status, notes in rows:
        suffix = f" ({notes})" if notes and notes != "-" else ""
        lines.append(f"- {label}: {status}{suffix}")
    return "\n".join(lines) + "\n\n"


def published_available(entry: dict) -> bool:
    return bool(
        entry.get("published_version") and entry.get("url")
        and entry["status"].startswith("published")
        and "source-only" not in entry["status"]
        and "shared implementation" not in entry["status"]
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
    examples = examples_line(directory)
    return (
        f"{BLOCK_START}\n\n"
        f"- Registry introduction: [REGISTRY.md]({prefix}/REGISTRY.md)\n"
        f"- Machine-readable entry: [llms.txt]({prefix}/llms.txt) and [llms.md]({prefix}/llms.md)\n"
        f"{examples}- Coding-agent contract: [docs/getting-started/coding-agents.md]({coding})\n"
        f"- Registry: {registry}\n"
        f"{community_entry()}"
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


def examples_line(directory: Path) -> str:
    if not (directory / "examples").is_dir():
        return ""
    relative = directory.relative_to(ROOT).as_posix()
    target = "examples" if relative == "." else f"{relative}/examples"
    return (
        f"- [Examples](https://github.com/axisvela/praxo-core/tree/main/{target}): "
        "runnable language-specific examples.\n"
    )


def scenario_links() -> str:
    return (
        "- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) "
        "([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): "
        "delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).\n"
        "- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) "
        "([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): "
        "candidate business goals and their existing related slices.\n"
        "- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) "
        "([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): "
        "cross-language tutorials, examples, and reference-application paths.\n"
    )


def content_links(directory: Path) -> str:
    lines = [scenario_links()]
    relative = directory.relative_to(ROOT).as_posix()
    key = "go" if directory == ROOT else directory.name
    entry = {"key": key, "dir": "." if key == "go" else relative}
    for folder, label in (
        ("Tutorial", "Scenario tutorials"),
        ("application", "Reference applications"),
    ):
        items = [
            item for item in _catalog_entries(ROOT, entry, folder)
            if item[0] != folder
        ]
        if items:
            lines.append(f"- {label}:\n")
            for name, target, description in items:
                lines.append(
                    f"  - [{name}](https://github.com/axisvela/praxo-core/tree/main/{target}): "
                    f"{description or 'See the tutorial README.'}\n"
                )
        elif folder == "application":
            lines.append(
                "- Reference applications: no accepted end-to-end application yet; "
                "candidate goals are tracked in the "
                "[Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).\n"
            )
    return "".join(lines)


def render_registry(entry: dict, directory: Path) -> str:
    summary = first_paragraph(directory / "README.md")
    registry = f"[{entry['registry']}]({entry['url']})" if entry["url"] else entry["registry"]
    published_version = published_version_label(entry)
    published_install = published_install_label(entry)
    examples = examples_line(directory)
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

{capabilities_registry(entry)}## Coding-agent entry

{examples}{content_links(directory)}- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract]({rel_link(ROOT / 'docs/getting-started/coding-agents.md', directory)}): explicit
  scope, final-argument authorization, denial tests, and verification commands.

{community_section()}## Boundaries

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
    examples = examples_line(directory)
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

{capabilities_llms(entry)}## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
{examples}{content_links(directory)}- Coding-agent contract: {coding}

{community_section()}## Boundaries

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

## Examples

- Task-oriented catalog: [docs Examples](docs/getting-started/examples.md)
- Repository catalog: [language/go/examples/README.md](language/go/examples/README.md)
- Live model: [language/go/examples/live-model](language/go/examples/live-model/README.md)
- Scenario tutorials: [language/go/Tutorial](language/go/Tutorial/README.md)
- Reference application: [language/go/application](language/go/application/README.md)
- Language examples: `language/<language>/examples/`
{scenario_links()}

{community_section()}## Boundaries

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
- Examples: https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/examples.md
- Examples directory: https://github.com/axisvela/praxo-core/blob/main/language/go/examples/README.md
- Live model: https://github.com/axisvela/praxo-core/blob/main/language/go/examples/live-model/README.md
- Scenario tutorials: https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial
- Reference application: https://github.com/axisvela/praxo-core/tree/main/language/go/application
{scenario_links()}- Start Here: https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/index.md
- Coding-agent contract: https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md
- Language repository index: https://github.com/axisvela/praxo-core/blob/main/docs/languages/repositories.md
- When Not To Use: https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/when-not-to-use.md

{community_section()}## Boundaries

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
                directory = registry.parent
                if registry.is_file() and registry.read_text(encoding="utf-8") != render_registry(entry, directory):
                    missing.append(f"{registry.relative_to(ROOT)}: stale registry entry")
                if llms_txt.is_file() and llms_txt.read_text(encoding="utf-8") != render_llms(entry, directory, markdown=False):
                    missing.append(f"{llms_txt.relative_to(ROOT)}: stale llms.txt entry")
                if llms_md.is_file() and llms_md.read_text(encoding="utf-8") != render_llms(entry, directory, markdown=True):
                    missing.append(f"{llms_md.relative_to(ROOT)}: stale llms.md entry")
        else:
            write_entry(entry)
    if args.check:
        if not MANIFEST.is_file():
            missing.append(str(MANIFEST.relative_to(ROOT)))
        elif json.loads(MANIFEST.read_text(encoding="utf-8")) != manifest_data():
            missing.append(f"{MANIFEST.relative_to(ROOT)}: stale registry metadata")
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
