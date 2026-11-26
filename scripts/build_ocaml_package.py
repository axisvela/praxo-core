"""Stage a local, reproducible OCaml source package from the canonical worktree."""

import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile


ROOT = Path(__file__).resolve().parents[1]
OWNER = ".ocaml-package.json"
GENERATOR = "scripts/build_ocaml_package.py"
REPOSITORY = "https://github.com/axisvela/praxo-core"
SRC_MODULES = [
    "praxo_types", "praxo_json", "praxo_toolcall", "praxo_schema",
    "praxo_manifest", "praxo_message", "praxo_provider_util",
    "praxo_openai", "praxo_anthropic", "praxo_gemini", "praxo_plugin",
    "praxo_runtime", "praxo_middleware", "praxo_agent", "praxo_seams",
]


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def git(root, *args, optional=False):
    result = subprocess.run(
        ["git", "--no-optional-locks", "-C", str(root), *args], capture_output=True, check=False,
        stdin=subprocess.DEVNULL, timeout=30,
    )
    if result.returncode and not optional:
        raise ValueError(result.stderr.decode(errors="replace").strip())
    return result.stdout.decode().strip() if result.returncode == 0 else None


def payload(root=ROOT):
    sdk = root / "language/ocaml"
    version = (sdk / "VERSION").read_text().strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("VERSION must be plain X.Y.Z")
    source = (sdk / "src/praxo_types.ml").read_bytes()
    versions = re.findall(rb'^let sdk_version = "([^"]+)"\s*$', source, re.M)
    if versions != [version.encode()]:
        raise ValueError("VERSION does not match praxo_types.ml sdk_version")
    files, inputs = {}, {}

    def copy(source_path, destination):
        safe_path(source_path)
        if source_path.is_symlink() or not source_path.is_file():
            raise ValueError(f"Not a regular source file: {source_path}")
        data = source_path.read_bytes()
        files[destination] = data
        inputs[source_path.relative_to(root).as_posix()] = data

    for name in ["praxo_core.ml", "praxo_core.mli"] + [module + ".ml" for module in SRC_MODULES]:
        copy(sdk / "src" / name, "src/" + name)
    for name in ("LICENSE", "CHANGELOG.md", "VERSION"):
        copy(sdk / name, name)
    copy(sdk / "api" / f"{version}.txt", f"api/{version}.txt")
    for name in ("praxo_tests.ml", "praxo_adapter_tests.ml"):
        copy(sdk / "tests" / name, "tests/" + name)
    copy(sdk / "tests/fixtures/process_plugin.py", "tests/tests/fixtures/process_plugin.py")
    if not (root / "spec/vectors").is_dir():
        raise ValueError("Missing shared spec/vectors directory")
    for path in sorted((root / "spec/vectors").rglob("*")):
        if path.is_file():
            copy(path, "tests/spec/vectors/" + path.relative_to(root / "spec/vectors").as_posix())
    inputs[GENERATOR] = (root / GENERATOR).read_bytes()

    metadata = f'''Source version: `{version}` (from `VERSION`).
opam package: `praxo-core`. Registry status: NOT published; publication pending.
Source availability is not registry publication; staging alone does not establish opam availability.

Independent OCaml runtime with an optional process plugin host.
Provider HTTP transport is caller-owned; no HTTP client or credentials are bundled.
Requires OCaml >= 4.14 and Dune >= 3.0; tests run in bytecode mode
and require Python 3. From this standalone source directory:

```sh
opam install . --with-test
```

Use `(libraries praxo-core)` and module `Praxo_core`.
See `PROVENANCE.json` for source HEAD and actual input hashes;
the canonical tag reference `ocaml/v{version}` does not certify packaged bytes.

- [Canonical tag reference]({REPOSITORY}/tree/ocaml/v{version})
- [Split development repository](https://github.com/axisvela/praxo-core-ocaml)
- [Documentation](https://axisvela.github.io/praxo-core/languages/ocaml/)
- [Coding agents](https://axisvela.github.io/praxo-core/getting-started/coding-agents/)
- [Examples]({REPOSITORY}/tree/main/language/ocaml/examples)
- [Security]({REPOSITORY}/blob/main/SECURITY.md)
'''
    for name in ("REGISTRY.md", "llms.md", "llms.txt"):
        files[name] = (f"# PRAXO-CORE OCaml {version}\n\n" + metadata).encode()

    files["dune-project"] = (
        f"(lang dune 3.0)\n(name praxo_core)\n(version {version})\n"
        "(generate_opam_files false)\n"
    ).encode()
    modules = " ".join(["praxo_core"] + SRC_MODULES)
    private_modules = " ".join(SRC_MODULES)
    files["src/dune"] = f"""(library
 (name praxo_core)
 (public_name praxo-core)
 (wrapped false)
 (modules {modules})
 (private_modules {private_modules})
 (libraries unix))
""".encode()
    files["tests/dune"] = b"""(test
 (name praxo_tests)
 (modes byte)
 (modules praxo_tests praxo_adapter_tests)
 (libraries praxo-core unix)
 (deps (source_tree spec) (source_tree tests))
 (action (run %{test} spec)))
"""
    files["praxo-core.opam"] = f'''opam-version: "2.0"
name: "praxo-core"
version: "{version}"
synopsis: "Embeddable native OCaml AI agent framework"
description: """
MIT-licensed native OCaml Core with agent execution, tools, memory,
checkpoints and provider transport seams. No bundled HTTP client.
"""
maintainer: "hanhuiwen <hanhuiwen@axisvela.com>"
authors: ["PRAXO-CORE contributors"]
license: "MIT"
homepage: "https://axisvela.github.io/praxo-core/languages/ocaml/"
doc: "https://axisvela.github.io/praxo-core/languages/ocaml/"
bug-reports: "{REPOSITORY}/issues"
dev-repo: "git+https://github.com/axisvela/praxo-core-ocaml.git"
depends: [
  "ocaml" {{>= "4.14"}}
  "dune" {{>= "3.0"}}
  "conf-python-3" {{with-test}}
]
build: [
  ["dune" "build" "-p" name "-j" jobs]
  ["dune" "runtest" "-p" name "-j" jobs] {{with-test}}
]
'''.encode()
    template = (root / "scripts/ocaml_package_readme.md").read_text(encoding="utf-8")
    inputs["scripts/ocaml_package_readme.md"] = template.encode()
    readme = template.replace("__VERSION__", version).replace("__REPOSITORY__", REPOSITORY)
    files["README.md"] = readme.encode()

    head = git(root, "rev-parse", "HEAD")
    object_format = git(root, "rev-parse", "--show-object-format")
    tree = git(root, "ls-tree", "-r", head)
    blobs = {}
    for line in tree.splitlines():
        metadata, path = line.split("\t", 1)
        blobs[path] = metadata.split()[2]
    records = {}
    for path, data in sorted(inputs.items()):
        oid = hashlib.new(object_format, b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        records[path] = {
            "worktree_sha256": sha256(data), "head_blob_oid": blobs.get(path),
            "matches_head": oid == blobs.get(path),
        }
    tag = f"ocaml/v{version}"
    files["PROVENANCE.json"] = json_bytes({
        "generator": GENERATOR, "canonical_repository": REPOSITORY,
        "version": version, "canonical_tag_reference": tag,
        "canonical_tag_commit": git(root, "rev-parse", "--verify", f"refs/tags/{tag}^{{commit}}", optional=True),
        "head_commit": head, "git_object_format": object_format,
        "identity_note": "Tag and HEAD are references only; worktree_sha256 identifies each actual input, not tagged content.",
        "inputs": records,
    })
    files[OWNER] = json_bytes({
        "generator": GENERATOR, "schema": 1,
        "files": {name: sha256(data) for name, data in sorted(files.items())},
    })
    return version, files


def safe_path(path):
    for part in (path, *path.parents):
        if part.is_symlink() or part.is_junction():
            raise ValueError(f"Refusing linked path: {part}")


def check_output(output, files, sync_split=False):
    safe_path(output)
    if output.exists() and not output.is_dir():
        raise ValueError(f"Output is not a directory: {output}")
    marker = output / OWNER
    safe_path(marker)
    tracked = set()
    if sync_split:
        if Path(git(output, "rev-parse", "--show-toplevel")) != output:
            raise ValueError("Split output must be the exact git top-level")
        origin = git(output, "remote", "get-url", "--all", "origin")
        if origin not in {
            f"{prefix}axisvela/praxo-core-ocaml{suffix}"
            for prefix in ("https://github.com/", "git@github.com:")
            for suffix in ("", ".git")
        }:
            raise ValueError("Split origin must be axisvela/praxo-core-ocaml on GitHub")
        if git(output, "status", "--porcelain", "--untracked-files=all"):
            raise ValueError("Split repository must have entirely clean git status")
        for entry in git(output, "ls-files", "--stage", "-z").split("\0"):
            if entry:
                metadata, name = entry.split("\t", 1)
                mode, _, stage = metadata.split()
                if mode in ("100644", "100755") and stage == "0":
                    tracked.add(name)
    owned = {}
    adopt = sync_split and not marker.exists()
    if marker.exists():
        record = json.loads(marker.read_bytes())
        if not isinstance(record, dict) or record.get("generator") != GENERATOR or record.get("schema") != 1:
            raise ValueError("Unrecognized ownership manifest")
        owned = record["files"]
        if not isinstance(owned, dict) or set(owned) - set(files):
            raise ValueError("Stale or invalid ownership manifest; use a fresh output directory")
    for name in files:
        pure = PurePosixPath(name)
        if pure.is_absolute() or ".." in pure.parts or ".git" in pure.parts:
            raise ValueError(f"Unsafe package path: {name}")
        target = output / name
        safe_path(target)
        for parent in target.parents:
            if parent.exists() and not parent.is_dir():
                raise ValueError(f"Parent is not a directory: {parent}")
        if target.exists():
            if not target.is_file():
                raise ValueError(f"Not a regular output file: {target}")
            if target.stat().st_nlink != 1:
                raise ValueError(f"Refusing hard-linked output file: {target}")
            if adopt:
                if name not in tracked:
                    raise ValueError(f"Refusing untracked managed file: {target}")
                owned[name] = sha256(target.read_bytes())
            if name == OWNER:
                continue
            if name not in owned or sha256(target.read_bytes()) != owned[name]:
                raise ValueError(f"Refusing unowned or edited file: {target}")


def archive_bytes(version, files):
    buffer = io.BytesIO()
    with gzip.GzipFile(fileobj=buffer, mode="wb", filename="", mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode="w", format=tarfile.USTAR_FORMAT) as tar:
            prefix = f"praxo-core-{version}"
            directories = {prefix}
            for name in files:
                directories.update(str(p) for p in PurePosixPath(prefix, name).parents if str(p) != ".")
            for name in sorted(directories):
                entry = tarfile.TarInfo(name)
                entry.type, entry.mode = tarfile.DIRTYPE, 0o755
                tar.addfile(entry)
            for name, data in sorted(files.items()):
                entry = tarfile.TarInfo(f"{prefix}/{name}")
                entry.size, entry.mode = len(data), 0o644
                tar.addfile(entry, io.BytesIO(data))
    return buffer.getvalue()


def stage(output, archive=None, root=ROOT, sync_split=False):
    output = Path(os.path.abspath(output))
    if output == root or output in root.parents or ".git" in [part.lower() for part in output.parts]:
        raise ValueError("Output must be a separate package directory outside .git")
    version, files = payload(root)
    check_output(output, files, sync_split)
    packed = None
    if archive is not None:
        archive = Path(os.path.abspath(archive))
        safe_path(archive)
        if ".git" in [part.lower() for part in archive.parts]:
            raise ValueError("Archive must be outside .git")
        if archive == output or output in archive.parents:
            raise ValueError("Archive must be outside the staged package")
        if archive.suffixes[-2:] != [".tar", ".gz"]:
            raise ValueError("Archive path must end in .tar.gz")
        packed = archive_bytes(version, files)
        if archive.exists() and (not archive.is_file() or archive.read_bytes() != packed):
            raise ValueError(f"Refusing to overwrite different archive: {archive}")
    for name, data in files.items():
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() or target.read_bytes() != data:
            with target.open("wb" if target.exists() else "xb") as stream:
                stream.write(data)
        target.chmod(0o644)
    if archive is not None:
        archive.parent.mkdir(parents=True, exist_ok=True)
        if not archive.exists():
            with archive.open("xb") as stream:
                stream.write(packed)
        print(f"sha256 {sha256(packed)}  {archive}")
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--archive", type=Path, help="optional deterministic .tar.gz (never replaces different bytes)")
    parser.add_argument("--sync-split", action="store_true", help="adopt tracked files in the clean OCaml split repository (requires --output)")
    args = parser.parse_args()
    if args.sync_split and args.output is None:
        parser.error("--sync-split requires explicit --output")
    output = args.output if args.output is not None else ROOT / "build/ocaml-package"
    try:
        files = stage(output, args.archive, sync_split=args.sync_split)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        parser.error(str(error))
    print(f"Staged {len(files)} files in {output}; staging alone does not establish opam availability")


if __name__ == "__main__":
    main()
