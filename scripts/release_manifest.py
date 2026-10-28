import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


MANIFEST = "release-manifest.json"
SUMS = "SHA256SUMS"


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_manifest(root, version, tag, sha, go_version, spec_version, sbom_scope):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("version must be X.Y.Z")
    if tag != f"v{version}":
        raise ValueError("tag must be v plus version")
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("sha must be a full lowercase commit SHA")
    if not go_version.strip() or not spec_version.strip() or not sbom_scope.strip():
        raise ValueError("go version, spec version, and SBOM scope are required")
    root = Path(root)
    root.mkdir(parents=True, exist_ok=True)
    artifacts = []
    for path in sorted(root.iterdir(), key=lambda item: item.name):
        if not path.is_file() or path.name in {MANIFEST, SUMS}:
            continue
        artifacts.append(
            {
                "name": path.name,
                "size": path.stat().st_size,
                "sha256": sha256(path),
            }
        )
    if not artifacts:
        raise ValueError("no release artifacts found")
    if not any(item["name"] == "sbom.json" for item in artifacts):
        raise ValueError("sbom.json is required")
    manifest = {
        "schema": "praxo-release-manifest-1",
        "version": version,
        "tag": tag,
        "git_sha": sha,
        "go_version": go_version.strip(),
        "spec_version": spec_version.strip(),
        "sbom": {"path": "sbom.json", "scope": sbom_scope.strip()},
        "artifacts": artifacts,
    }
    manifest_path = root / MANIFEST
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    checksummed = artifacts + [
        {
            "name": MANIFEST,
            "size": manifest_path.stat().st_size,
            "sha256": sha256(manifest_path),
        }
    ]
    lines = [
        f'{item["sha256"]}  {item["name"]}'
        for item in sorted(checksummed, key=lambda item: item["name"])
    ]
    (root / SUMS).write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    return manifest


def main(argv=None):
    parser = argparse.ArgumentParser(description="Build release evidence manifest and checksums")
    parser.add_argument("--root", default="dist")
    parser.add_argument("--version", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--go-version", required=True)
    parser.add_argument("--spec-version", required=True)
    parser.add_argument("--sbom-scope", required=True)
    args = parser.parse_args(argv)
    try:
        manifest = build_manifest(
            args.root,
            args.version,
            args.tag,
            args.sha,
            args.go_version,
            args.spec_version,
            args.sbom_scope,
        )
    except (OSError, ValueError) as error:
        print(f"Release manifest failed: {error}", file=sys.stderr)
        return 1
    print(
        f"wrote {Path(args.root) / MANIFEST} with {len(manifest['artifacts'])} artifacts"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
