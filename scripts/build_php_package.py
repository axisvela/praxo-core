import argparse
import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
DOCUMENTS = (
    "README.md", "REGISTRY.md", "llms.md", "llms.txt", "LICENSE", "CHANGELOG.md",
)


def payload(root=ROOT):
    sdk = root / "language/php"
    metadata = json.loads((sdk / "composer.json").read_text(encoding="utf-8"))
    version = metadata.pop("version")
    metadata.pop("scripts", None)
    files = {}
    for directory in ("src", "api"):
        source = sdk / directory
        if not source.is_dir() or source.is_symlink():
            raise ValueError(f"Missing regular source directory: {source}")
        for path in sorted(source.rglob("*")):
            if path.is_symlink():
                raise ValueError(f"Symlink is not a package input: {path}")
            if path.is_file():
                files[path.relative_to(sdk).as_posix()] = path.read_bytes()
    for name in DOCUMENTS:
        path = sdk / name
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Missing regular document: {path}")
        files[name] = path.read_bytes()
    for name in ("src/autoload.php", "src/PluginProcessHost.php", f"api/{version}.txt"):
        if name not in files:
            raise ValueError(f"Missing required package input: {name}")
    for name in metadata["autoload"]["files"]:
        if name not in files:
            raise ValueError(f"Missing Composer autoload input: {name}")
    files["composer.json"] = (json.dumps(metadata, indent=2) + "\n").encode()
    return version, files


def check(output, files):
    if output.is_symlink() or not output.is_dir():
        raise ValueError(f"Not a regular package directory: {output}")
    actual = {}
    for path in output.rglob("*"):
        relative = path.relative_to(output)
        if relative.parts[0] == ".git":
            continue
        if path.is_symlink():
            raise ValueError(f"Symlink is not a package file: {path}")
        if path.is_file():
            actual[relative.as_posix()] = path.read_bytes()
    missing = sorted(files.keys() - actual.keys())
    extra = sorted(actual.keys() - files.keys())
    changed = sorted(name for name in files.keys() & actual.keys() if files[name] != actual[name])
    if missing or extra or changed:
        raise ValueError(f"Package mismatch: missing={missing}, extra={extra}, changed={changed}")


def stage(output, files):
    if output.is_symlink() or (output.exists() and (not output.is_dir() or any(output.iterdir()))):
        raise ValueError(f"Refusing to overwrite nonempty output: {output}")
    output.mkdir(parents=True, exist_ok=True)
    for name, data in sorted(files.items()):
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    check(output, files)


def sync_checkout(output, files):
    output = output.resolve()
    if not (output / ".git").is_dir():
        raise ValueError("Split synchronization requires a standalone Git checkout")

    def git(*arguments):
        return subprocess.check_output(["git", "-C", str(output), *arguments], text=True).strip()

    if Path(git("rev-parse", "--show-toplevel")).resolve() != output:
        raise ValueError("Output must be the split repository root")
    remote = git("remote", "get-url", "origin").removesuffix(".git")
    if remote not in {"https://github.com/axisvela/praxo-core-php", "git@github.com:axisvela/praxo-core-php"}:
        raise ValueError("Refusing to synchronize an unexpected split remote")
    if git("status", "--porcelain", "--untracked-files=all", "--ignored"):
        raise ValueError("Refusing to synchronize a dirty split checkout")
    paths = [path for path in output.rglob("*") if ".git" not in path.relative_to(output).parts]
    if any(path.is_symlink() for path in paths):
        raise ValueError("Refusing symlinked split contents")
    for path in sorted(paths, key=lambda item: len(item.parts), reverse=True):
        if path.is_dir():
            path.rmdir()
        else:
            path.unlink()
    for name, data in sorted(files.items()):
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    check(output, files)


def main():
    parser = argparse.ArgumentParser(description="Stage or verify the canonical PHP split artifact.")
    parser.add_argument("--output", type=Path, required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--sync-split", action="store_true", help="replace a clean PHP split checkout payload, preserving .git")
    args = parser.parse_args()
    try:
        version, files = payload()
        if args.check:
            check(args.output, files)
        elif args.sync_split:
            sync_checkout(args.output, files)
        else:
            stage(args.output, files)
    except (ValueError, OSError, KeyError) as error:
        parser.exit(1, f"{error}\n")
    print(f"PHP {version}: {'verified' if args.check else 'staged'} {len(files)} files at {args.output}")


if __name__ == "__main__":
    main()
