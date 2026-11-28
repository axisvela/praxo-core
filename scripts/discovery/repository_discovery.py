"""Print or validate a local repository topics proposal; never mutate GitHub."""

import argparse
import json
import re

from scripts.discovery.registry_discovery import CONFIG, ROOT, discovery


def proposal(manifest: dict) -> dict:
    repositories = {
        "axisvela/praxo-core": {"kind": "canonical", "topics": CONFIG["canonical_topics"]}
    }
    seen = set()
    for entry in manifest.values():
        expected = discovery(entry)
        if entry.get("discovery") != expected:
            raise ValueError(f"stale discovery metadata: {entry['dir']}")
        if expected["repository_kind"] == "shared-source":
            continue
        key = "go" if entry["dir"] == "." else entry["dir"].rsplit("/", 1)[-1]
        seen.add(key)
        repository = expected["repository"]
        if repository in repositories:
            raise ValueError(f"duplicate repository: {repository}")
        repositories[repository] = {
            "kind": expected["repository_kind"], "topics": expected["topics"]
        }
    if seen != set(CONFIG["language_topics"]):
        raise ValueError("language topic configuration must cover exactly the independent SDKs")
    if not set(CONFIG["split_sources"]) <= seen or not set(CONFIG["repository_overrides"]) <= seen:
        raise ValueError("unknown split source or repository override")
    for repository, entry in repositories.items():
        if not re.fullmatch(r"axisvela/praxo-core(?:-[A-Za-z0-9-]+)?", repository):
            raise ValueError(f"invalid repository: {repository}")
        topics = entry["topics"]
        if not 1 <= len(topics) <= 20 or len(set(topics)) != len(topics):
            raise ValueError(f"invalid topic count or duplicates: {repository}")
        if not set(CONFIG["aliases"]) <= set(topics):
            raise ValueError(f"missing product aliases: {repository}")
        if any(not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,49}", topic) for topic in topics):
            raise ValueError(f"invalid topic syntax: {repository}")
    return repositories


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate local configuration without printing the proposal")
    args = parser.parse_args()
    manifest = json.loads((ROOT / "language/registry-metadata.json").read_text(encoding="utf-8"))
    try:
        repositories = proposal(manifest)
    except (KeyError, ValueError) as error:
        print(str(error))
        return 1
    if args.check:
        print(f"Validated {len(repositories)} repository topic proposals; no remote changes.")
    else:
        print(json.dumps(repositories, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
