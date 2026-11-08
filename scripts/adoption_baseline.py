#!/usr/bin/env python3
"""Validate a coding-agent adoption baseline manifest.

The manifest pre-registers a task set, track, pinned versions, permissions and
budgets. This tool validates structure only; it does not run a coding tool or
produce adoption results.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

TRACKS = {"free-selection", "directed-integration", "upgrade-maintenance"}
KINDS = {"regression", "unseen"}
TOP_LEVEL = ("schemaVersion", "protocol", "tool", "model", "environment", "budgets", "tasks")


class ManifestError(Exception):
    pass


def _require_text(value: object, field: str, errors: list[str]) -> None:
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{field}: non-empty string required")


def _require_object(value: object, field: str, errors: list[str]) -> dict[str, object] | None:
    if not isinstance(value, dict):
        errors.append(f"{field}: object required")
        return None
    return value


def validate_manifest(data: object) -> Counter:
    if not isinstance(data, dict):
        raise ManifestError("manifest: object required")
    errors: list[str] = []
    for field in TOP_LEVEL:
        if field not in data:
            errors.append(f"{field}: required")
    if data.get("schemaVersion") != 1:
        errors.append("schemaVersion: must be 1")
    _require_text(data.get("protocol"), "protocol", errors)

    for section in ("tool", "model"):
        value = _require_object(data.get(section), section, errors)
        if value is not None:
            _require_text(value.get("name"), f"{section}.name", errors)
            _require_text(value.get("version"), f"{section}.version", errors)

    environment = _require_object(data.get("environment"), "environment", errors)
    if environment is not None:
        _require_text(environment.get("os"), "environment.os", errors)
        _require_text(environment.get("toolchain"), "environment.toolchain", errors)
        permissions = _require_object(environment.get("permissions"), "environment.permissions", errors)
        if permissions is not None:
            for key in ("search", "execute"):
                if not isinstance(permissions.get(key), bool):
                    errors.append(f"environment.permissions.{key}: boolean required")

    budgets = _require_object(data.get("budgets"), "budgets", errors)
    if budgets is not None:
        for key in ("maxSteps", "timeoutSeconds"):
            value = budgets.get(key)
            if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
                errors.append(f"budgets.{key}: positive integer required")

    tasks = data.get("tasks")
    if not isinstance(tasks, list) or not tasks:
        errors.append("tasks: non-empty list required")
        tasks = []

    counts: Counter = Counter()
    seen: set[str] = set()
    for index, task in enumerate(tasks):
        field = f"tasks[{index}]"
        if not isinstance(task, dict):
            errors.append(f"{field}: object required")
            continue
        task_id = task.get("id")
        if not isinstance(task_id, str) or not task_id.strip():
            errors.append(f"{field}.id: non-empty string required")
        elif task_id in seen:
            errors.append(f"{field}.id: duplicate {task_id!r}")
        else:
            seen.add(task_id)
        kind = task.get("kind")
        if kind not in KINDS:
            errors.append(f"{field}.kind: one of {sorted(KINDS)} required")
        track = task.get("track")
        if track not in TRACKS:
            errors.append(f"{field}.track: one of {sorted(TRACKS)} required")
        if not isinstance(task.get("suitable"), bool):
            errors.append(f"{field}.suitable: boolean required")
        prompt = task.get("prompt")
        if not isinstance(prompt, str) or not prompt.strip():
            errors.append(f"{field}.prompt: non-empty string required")
        _require_text(task.get("packageVersion"), f"{field}.packageVersion", errors)
        acceptance = task.get("acceptance")
        if not isinstance(acceptance, list) or not acceptance:
            errors.append(f"{field}.acceptance: non-empty list required")
        else:
            for item_index, item in enumerate(acceptance):
                _require_text(item, f"{field}.acceptance[{item_index}]", errors)
        if track == "free-selection" and isinstance(prompt, str) and "praxo-core" in prompt.lower():
            errors.append(f"{field}.prompt: free-selection prompt must not name PRAXO-CORE")
        if track == "directed-integration" and isinstance(prompt, str) and "praxo-core" not in prompt.lower():
            errors.append(f"{field}.prompt: directed-integration prompt must name PRAXO-CORE")
        if track == "upgrade-maintenance":
            _require_text(task.get("baselineVersion"), f"{field}.baselineVersion", errors)
            _require_text(task.get("targetVersion"), f"{field}.targetVersion", errors)
        if kind in KINDS and track in TRACKS:
            counts[(kind, track)] += 1

    if errors:
        raise ManifestError("\n".join(errors))
    return counts


def load_manifest(path: Path) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except OSError as error:
        raise ManifestError(f"cannot read {path}: {error}") from error
    except json.JSONDecodeError as error:
        raise ManifestError(f"invalid JSON in {path}: {error}") from error


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path, help="adoption baseline manifest JSON")
    args = parser.parse_args(argv)
    try:
        counts = validate_manifest(load_manifest(args.manifest))
    except ManifestError as error:
        print(error, file=sys.stderr)
        return 1
    kinds = Counter()
    tracks = Counter()
    for (kind, track), count in counts.items():
        kinds[kind] += count
        tracks[track] += count
    print(
        f"adoption manifest valid: {sum(counts.values())} tasks; "
        f"kinds={dict(sorted(kinds.items()))}; tracks={dict(sorted(tracks.items()))}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
