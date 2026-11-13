#!/usr/bin/env python3
"""Refresh dedicated language mirror repositories from the monorepo.

The monorepo is canonical. This script rebuilds the discovery mirrors from
``language/<language>`` plus ``spec/`` and pushes only when the tree changed.
Publication-source repositories (Ruby, PHP, Lua, Swift, Julia, V, OCaml, Nim, D)
are intentionally excluded because they have their own release layouts and
workflows.

Requires a token with push access to the mirror repositories. Pass it through
``PRAXO_MIRROR_TOKEN`` or ``--token-env``. The token is never printed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORGANIZATION = "axisvela"
REPO_PREFIX = "praxo-core-"
DEFAULT_TOKEN_ENV = "PRAXO_MIRROR_TOKEN"
MIRROR_KEYS = [
    "python",
    "typescript",
    "java",
    "rust",
    "csharp",
    "r",
    "elixir",
    "erlang",
    "perl",
    "haskell",
    "dart",
    "zig",
    "c",
    "cpp",
    "fortran",
    "cobol",
    "powershell",
    "matlab",
    "octave",
    "delphi",
    "objc",
]
EXTRA_SOURCES = {
    "matlab": ["language/matlab-octave-core"],
    "octave": ["language/matlab-octave-core"],
}
IGNORED_DIRECTORIES = {
    "build",
    "target",
    "dist",
    "node_modules",
    "_build",
    "deps",
    "out",
    "out-test",
    "bin",
    "obj",
    ".Rcheck",
    "__pycache__",
    ".elixir_ls",
    "blib",
    "dist-newstyle",
    ".stack-work",
    ".dart_tool",
    "zig-cache",
    "zig-out",
    ".pytest_cache",
}
IGNORED_SUFFIXES = (".pyc", ".pyo")
IGNORED_FILES = {"pubspec.lock", ".DS_Store", "Thumbs.db"}
GIT_IDENTITY = ("hanhuiwen", "hanhuiwen@axisvela.com")


def mirror_entries(root: Path = ROOT) -> list[dict]:
    manifest = json.loads(
        (root / "language" / "registry-metadata.json").read_text(encoding="utf-8")
    )
    by_key = {}
    for name, entry in manifest.items():
        key = Path(entry["dir"]).name
        by_key[key] = {
            "key": key,
            "name": name,
            "package": entry["package"],
            "published_version": entry["published_version"],
            "registry": entry["registry"],
            "install": entry["install"],
            "docs": entry["docs"],
            "source_dirs": [entry["dir"], *EXTRA_SOURCES.get(key, [])],
        }
    missing = [key for key in MIRROR_KEYS if key not in by_key]
    if missing:
        raise SystemExit("missing mirror metadata: " + ", ".join(missing))
    return [by_key[key] for key in MIRROR_KEYS]


def mirror_readme(entry: dict, has_examples: bool = False) -> str:
    install = entry["install"]
    examples = ""
    if has_examples:
        examples = (
            f"- Examples: https://github.com/{ORGANIZATION}/{REPO_PREFIX}{entry['key']}"
            f"/tree/main/language/{entry['key']}/examples\n"
        )
    return f"""# PRAXO-CORE for {entry['name']}

Dedicated repository for the {entry['name']} implementation of PRAXO-CORE: an
embeddable, MIT-licensed agent execution kernel with policy controls,
human-in-the-loop approval, checkpoints, events, and tool calling.

- Package: `{entry['package']}` (`{entry['published_version']}`)
- Registry: {entry['registry']}
- Install: `{install}`
- Documentation: {entry['docs']}
{examples}- Mirror repository: https://github.com/{ORGANIZATION}/{REPO_PREFIX}{entry['key']}
- Canonical source: https://github.com/{ORGANIZATION}/praxo-core/tree/main/language/{entry['key']}
- Release index: https://axisvela.github.io/praxo-core/languages/registry-status/

This repository is a discovery mirror of the canonical {entry['name']} source.
The monorepo remains the source of truth and the release workflow source. Shared
conformance vectors are included under `spec/`, so the implementation can be
built and tested here.

## Verify

Build and test instructions are in `language/{entry['key']}/README.md`. The
monorepo CI runs the language's conformance, API snapshot, and native tests.

PRAXO-CORE is not a hosted model, workflow engine, identity provider, or safety
controller. Do not infer exactly-once execution, complete sandbox isolation,
production security certification, live-provider behavior, or physical safety
from this package.

MIT licensed.
"""


def mirror_gitignore() -> str:
    return (
        "build/\n"
        "target/\n"
        "dist/\n"
        "node_modules/\n"
        "__pycache__/\n"
        "*.pyc\n"
        "*.pyo\n"
    )


def _ignore(directory: str, names: list[str]) -> set[str]:
    ignored = set()
    for name in names:
        if name in IGNORED_DIRECTORIES or name in IGNORED_FILES:
            ignored.add(name)
        elif name.endswith(IGNORED_SUFFIXES):
            ignored.add(name)
        elif name.endswith(".egg-info"):
            ignored.add(name)
    return ignored


def build_mirror(entry: dict, destination: Path, root: Path = ROOT, clean: bool = True) -> None:
    if clean and destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True, exist_ok=True)
    for relative in entry["source_dirs"]:
        source = root / relative
        if not source.is_dir():
            raise SystemExit(f"missing source directory: {source}")
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, target, ignore=_ignore)
    spec_source = root / "spec"
    if spec_source.is_dir():
        shutil.copytree(spec_source, destination / "spec", ignore=_ignore)
    shutil.copy2(root / "LICENSE", destination / "LICENSE")
    has_examples = (root / "language" / entry["key"] / "examples").is_dir()
    (destination / "README.md").write_text(
        mirror_readme(entry, has_examples=has_examples), encoding="utf-8"
    )
    (destination / ".gitignore").write_text(mirror_gitignore(), encoding="utf-8")


def tree_digest(directory: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(directory.rglob("*")):
        if not path.is_file() or ".git" in path.parts:
            continue
        relative = path.relative_to(directory).as_posix()
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
    return digest.hexdigest()


def run_git(arguments: list[str], cwd: Path, token: str | None = None) -> str:
    result = subprocess.run(
        ["git", "-c", f"user.name={GIT_IDENTITY[0]}", "-c", f"user.email={GIT_IDENTITY[1]}", *arguments],
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        command = " ".join(arguments)
        error = result.stderr.strip()
        if token:
            command = command.replace(token, "***")
            error = error.replace(token, "***")
        raise SystemExit(f"git {command} failed:\n{error}")
    return result.stdout.strip()


def clone_url(entry: dict, token: str | None) -> str:
    repo = f"{ORGANIZATION}/{REPO_PREFIX}{entry['key']}.git"
    if token:
        return f"https://x-access-token:{token}@github.com/{repo}"
    return f"https://github.com/{repo}"


def repository_dir(entry: dict, token: str | None, workdir: Path) -> Path:
    destination = workdir / f"{REPO_PREFIX}{entry['key']}"
    run_git(["clone", "--quiet", "--depth", "1", clone_url(entry, token), str(destination)], workdir, token)
    for child in destination.iterdir():
        if child.name == ".git":
            continue
        if child.is_dir():
            shutil.rmtree(child)
        else:
            child.unlink()
    return destination


def sync(entry: dict, token: str, workdir: Path, check: bool, revision: str) -> bool:
    destination = repository_dir(entry, token, workdir)
    build_mirror(entry, destination, clean=False)
    run_git(["add", "-A"], destination, token)
    status = run_git(["status", "--porcelain"], destination, token)
    if not status:
        return False
    if check:
        print(f"DRIFT {entry['key']}: {len(status.splitlines())} changed path(s)")
        for line in status.splitlines():
            print(f"  {line}")
        return True
    message = f"sync: refresh {entry['name']} mirror from monorepo {revision}"
    run_git(["commit", "-m", message], destination, token)
    run_git(["push", "--quiet", "origin", "HEAD:main"], destination, token)
    print(f"SYNCED {entry['key']}")
    return True


def parse_only(value: str | None) -> list[str] | None:
    if not value:
        return None
    keys = [item.strip() for item in value.split(",") if item.strip()]
    unknown = [key for key in keys if key not in MIRROR_KEYS]
    if unknown:
        raise SystemExit("unknown mirror key(s): " + ", ".join(unknown))
    return keys


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="clone and report drift without pushing")
    parser.add_argument("--dry-run", action="store_true", help="build temporary trees without cloning")
    parser.add_argument("--only", help="comma-separated mirror keys")
    parser.add_argument("--token-env", default=DEFAULT_TOKEN_ENV)
    parser.add_argument("--revision", default=os.environ.get("GITHUB_SHA", "unknown"))
    args = parser.parse_args(argv)

    keys = parse_only(args.only)
    entries = [entry for entry in mirror_entries() if keys is None or entry["key"] in keys]
    token = os.environ.get(args.token_env, "")
    if not args.dry_run and not args.check and not token:
        print(f"missing {args.token_env}; set a token with push access to the mirror repositories", file=sys.stderr)
        return 2

    changed = 0
    with tempfile.TemporaryDirectory(prefix="praxo-mirrors-") as directory:
        workdir = Path(directory)
        for entry in entries:
            if args.dry_run:
                target = workdir / entry["key"]
                build_mirror(entry, target)
                print(f"BUILT {entry['key']}: {tree_digest(target)[:12]}")
                changed += 1
                continue
            if sync(entry, token, workdir, args.check, args.revision):
                changed += 1
    print(f"{'drifted' if args.check else 'updated'} {changed}/{len(entries)} mirror(s)")
    return 1 if args.check and changed else 0


if __name__ == "__main__":
    raise SystemExit(main())
