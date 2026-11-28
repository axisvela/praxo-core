import argparse
import json
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
VERSION_PATTERN = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Read-only check of GitHub's public Latest release.")
    parser.add_argument("--repository", default="axisvela/praxo-core")
    parser.add_argument("--expected-version", help="Plain X.Y.Z; defaults to root VERSION")
    args = parser.parse_args(argv)
    try:
        version = args.expected_version or (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        if not re.fullmatch(VERSION_PATTERN, version):
            raise ValueError(f"expected plain X.Y.Z, got {version!r}")
        if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository):
            raise ValueError("repository must be OWNER/REPO")
    except (OSError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1

    expected = f"v{version}"
    errors = []
    releases = {}
    for label, endpoint in (("Latest", "latest"), (expected, f"tags/{expected}")):
        command = ["gh", "api", "--method", "GET",
                   f"repos/{args.repository}/releases/{endpoint}"]
        try:
            result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=30)
            release = json.loads(result.stdout)
            if not isinstance(release, dict) or not isinstance(release.get("tag_name"), str):
                raise ValueError("invalid release response")
            releases[label] = release
            print(f"{label}: {release['tag_name']}")
            if release.get("draft") is not False or release.get("prerelease") is not False:
                errors.append(f"{label} must be a published, non-prerelease release")
        except subprocess.CalledProcessError as error:
            detail = (error.stderr or "").strip()
            if "404" in detail:
                errors.append(f"PENDING: missing {label} release; complete the approved release process")
            else:
                errors.append(f"cannot verify {label} release: {detail or str(error)}")
        except (OSError, subprocess.TimeoutExpired, ValueError) as error:
            errors.append(f"cannot verify {label} release: {error}")

    latest = releases.get("Latest", {}).get("tag_name")
    if latest is not None:
        if not re.fullmatch(f"v{VERSION_PATTERN}", latest):
            errors.append(f"Latest must use a root Go tag vX.Y.Z, not {latest!r}")
        elif latest != expected:
            errors.append(f"PENDING: Latest is {latest}, expected {expected}; review release designation")
    if expected in releases and releases[expected]["tag_name"] != expected:
        errors.append(f"expected release must use tag {expected}")
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    if errors:
        print("Read-only check; no release was created, published, or changed.", file=sys.stderr)
        return 1
    print(f"PASS: GitHub Latest matches expected root Go release {expected}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
