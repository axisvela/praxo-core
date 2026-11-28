"""Collect public package-registry download metrics.

The collector stores immutable daily snapshots plus a long-form series for
language/channel analysis. It uses only standard-library HTTP and does not
publish packages or mutate registry state.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Iterable

ROOT = Path(__file__).resolve().parents[2]
METADATA = ROOT / "language" / "registry-metadata.json"
DEFAULT_OUTPUT = ROOT / "data" / "registry-downloads"
SCHEMA = 1
SERIES_HEADER = (
    "date",
    "language",
    "registry",
    "channel",
    "package",
    "version",
    "status",
    "metric",
    "value",
)
METRIC_NAMES = ("total", "last_day", "last_week", "last_month")
USER_AGENT = "praxo-core-registry-metrics/1.0 (+https://github.com/axisvela/praxo-core)"

CHANNEL_BY_LANGUAGE = {
    "Python": ("pypi", "PyPI"),
    "TypeScript": ("npm", "npm"),
    "Rust": ("crates", "crates.io"),
    "C#": ("nuget", "NuGet"),
    "Ruby": ("rubygems", "RubyGems"),
    "PHP": ("packagist", "Packagist"),
    "Elixir": ("hex", "Hex"),
    "Erlang": ("hex", "Hex"),
    "Dart": ("pub", "pub.dev"),
    "PowerShell": ("powershell", "PowerShell Gallery"),
}

Fetcher = Callable[[str], bytes]


@dataclass(frozen=True)
class Target:
    language: str
    package: str
    registry: str
    channel: str
    expected_version: str
    url: str
    status: str


def load_targets(metadata_path: Path = METADATA) -> list[Target]:
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    targets: list[Target] = []
    for language, (channel, registry) in CHANNEL_BY_LANGUAGE.items():
        entry = metadata.get(language)
        if not entry:
            continue
        targets.append(
            Target(
                language=language,
                package=str(entry.get("package", "")),
                registry=registry,
                channel=channel,
                expected_version=str(entry.get("published_version") or entry.get("version") or ""),
                url=str(entry.get("url", "")),
                status=str(entry.get("status", "")),
            )
        )
    return targets


def fetch_bytes(url: str, timeout: float, user_agent: str = USER_AGENT) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": user_agent})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def _json(fetch: Fetcher, url: str) -> Any:
    return json.loads(fetch(url).decode("utf-8"))


def _int(value: Any) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def _empty_result() -> dict[str, Any]:
    return {"status": "ok", "metrics": {}, "versions": [], "source": ""}


def collect_pypi(target: Target, fetch: Fetcher) -> dict[str, Any]:
    result = _empty_result()
    info = _json(fetch, f"https://pypi.org/pypi/{urllib.parse.quote(target.package)}/json")
    result["source"] = "pypi.org + pypistats.org"
    result["version"] = str(info.get("info", {}).get("version") or target.expected_version)
    try:
        recent = _json(
            fetch,
            f"https://pypistats.org/api/packages/{urllib.parse.quote(target.package)}/recent",
        )
        data = recent.get("data", {})
        result["metrics"] = {
            "last_day": _int(data.get("last_day")),
            "last_week": _int(data.get("last_week")),
            "last_month": _int(data.get("last_month")),
        }
    except Exception as error:  # PyPI itself has no official download API.
        result["status"] = "partial"
        result["error"] = f"pypistats unavailable: {error}"
    return result


def collect_npm(target: Target, fetch: Fetcher) -> dict[str, Any]:
    result = _empty_result()
    encoded = urllib.parse.quote(target.package, safe="@")
    result["source"] = "api.npmjs.org"
    latest = _json(fetch, f"https://registry.npmjs.org/{encoded}/latest")
    result["version"] = str(latest.get("version") or target.expected_version)
    metrics = {}
    for metric, period in (("last_day", "last-day"), ("last_week", "last-week"), ("last_month", "last-month")):
        point = _json(fetch, f"https://api.npmjs.org/downloads/point/{period}/{encoded}")
        metrics[metric] = _int(point.get("downloads"))
    result["metrics"] = metrics
    versions = _json(fetch, f"https://api.npmjs.org/versions/{encoded}/last-week")
    result["versions"] = [
        {"version": str(version), "downloads": _int(downloads)}
        for version, downloads in sorted(versions.get("downloads", {}).items())
    ]
    return result


def collect_crates(target: Target, fetch: Fetcher) -> dict[str, Any]:
    result = _empty_result()
    result["source"] = "crates.io API"
    data = _json(fetch, f"https://crates.io/api/v1/crates/{urllib.parse.quote(target.package)}")
    crate = data.get("crate", {})
    result["version"] = str(crate.get("max_version") or target.expected_version)
    result["metrics"] = {
        "total": _int(crate.get("downloads")),
        "last_month": _int(crate.get("recent_downloads")),
    }
    result["versions"] = [
        {"version": str(item.get("num", "")), "downloads": _int(item.get("downloads"))}
        for item in data.get("versions", [])
    ]
    return result


def collect_nuget(target: Target, fetch: Fetcher) -> dict[str, Any]:
    result = _empty_result()
    result["source"] = "azuresearch-usnc.nuget.org"
    query = urllib.parse.quote(f"packageid:{target.package}")
    data = _json(
        fetch,
        f"https://azuresearch-usnc.nuget.org/query?q={query}&prerelease=true&semVerLevel=2.0.0",
    )
    packages = data.get("data", [])
    if not packages:
        raise ValueError(f"NuGet package not found: {target.package}")
    package = packages[0]
    result["version"] = str(package.get("version") or target.expected_version)
    result["metrics"] = {"total": _int(package.get("totalDownloads"))}
    result["versions"] = [
        {"version": str(item.get("version", "")), "downloads": _int(item.get("downloads"))}
        for item in package.get("versions", [])
    ]
    return result


def collect_rubygems(target: Target, fetch: Fetcher) -> dict[str, Any]:
    result = _empty_result()
    result["source"] = "rubygems.org API"
    gem = _json(fetch, f"https://rubygems.org/api/v1/gems/{urllib.parse.quote(target.package)}.json")
    result["version"] = str(gem.get("version") or target.expected_version)
    result["metrics"] = {"total": _int(gem.get("downloads"))}
    versions = _json(
        fetch,
        f"https://rubygems.org/api/v1/versions/{urllib.parse.quote(target.package)}.json",
    )
    result["versions"] = [
        {"version": str(item.get("number", "")), "downloads": _int(item.get("downloads_count"))}
        for item in versions
    ]
    return result


def collect_packagist(target: Target, fetch: Fetcher) -> dict[str, Any]:
    result = _empty_result()
    result["source"] = "packagist.org API"
    data = _json(fetch, f"https://packagist.org/packages/{target.package}.json")
    package = data.get("package", {})
    downloads = package.get("downloads", {})
    result["version"] = str(target.expected_version)
    result["metrics"] = {
        "total": _int(downloads.get("total")),
        "last_day": _int(downloads.get("daily")),
        "last_month": _int(downloads.get("monthly")),
    }
    return result


def collect_hex(target: Target, fetch: Fetcher) -> dict[str, Any]:
    result = _empty_result()
    result["source"] = "hex.pm API"
    package = _json(fetch, f"https://hex.pm/api/packages/{urllib.parse.quote(target.package)}")
    result["version"] = str(target.expected_version)
    downloads = package.get("downloads", {})
    result["metrics"] = {
        "total": _int(downloads.get("all")),
        "last_day": _int(downloads.get("day")),
        "last_week": _int(downloads.get("week")),
    }
    result["versions"] = [
        {"version": str(item.get("version", "")), "downloads": _int(item.get("downloads"))}
        for item in package.get("releases", [])
    ]
    return result


def collect_pub(target: Target, fetch: Fetcher) -> dict[str, Any]:
    result = _empty_result()
    result["source"] = "pub.dev API"
    package = _json(fetch, f"https://pub.dev/api/packages/{urllib.parse.quote(target.package)}")
    result["version"] = str(package.get("latest", {}).get("version") or target.expected_version)
    try:
        score = _json(fetch, f"https://pub.dev/api/packages/{urllib.parse.quote(target.package)}/score")
        result["metrics"] = {"last_month": _int(score.get("downloadCount30Days"))}
    except Exception as error:
        result["status"] = "partial"
        result["error"] = f"pub.dev score unavailable: {error}"
    return result


def collect_powershell(target: Target, fetch: Fetcher) -> dict[str, Any]:
    result = _empty_result()
    result["source"] = "powershellgallery.com OData"
    url = (
        "https://www.powershellgallery.com/api/v2/FindPackagesById()"
        f"?id='{urllib.parse.quote(target.package)}'"
    )
    root = ET.fromstring(fetch(url))
    namespaces = {"a": "http://www.w3.org/2005/Atom", "d": "http://schemas.microsoft.com/ado/2007/08/dataservices"}
    versions = []
    for entry in root.findall("a:entry", namespaces):
        version = entry.findtext("a:properties/d:Version", namespaces=namespaces)
        downloads = entry.findtext("a:properties/d:DownloadCount", namespaces=namespaces)
        if version:
            versions.append({"version": version, "downloads": _int(int(downloads)) if downloads else None})
    if not versions:
        raise ValueError(f"PowerShell package not found: {target.package}")
    result["version"] = versions[0]["version"]
    result["metrics"] = {
        "total": sum(item["downloads"] or 0 for item in versions),
    }
    result["versions"] = versions
    return result


PROVIDERS = {
    "pypi": collect_pypi,
    "npm": collect_npm,
    "crates": collect_crates,
    "nuget": collect_nuget,
    "rubygems": collect_rubygems,
    "packagist": collect_packagist,
    "hex": collect_hex,
    "pub": collect_pub,
    "powershell": collect_powershell,
}


def collect_targets(
    targets: Iterable[Target],
    fetch: Fetcher,
    collected_at: str,
) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for target in targets:
        provider = PROVIDERS.get(target.channel)
        if provider is None:
            result = {
                "status": "unavailable",
                "metrics": {},
                "versions": [],
                "source": "",
                "error": "no public download-metric API configured",
            }
        else:
            try:
                result = provider(target, fetch)
            except Exception as error:
                result = {
                    "status": "error",
                    "metrics": {},
                    "versions": [],
                    "source": "",
                    "error": str(error),
                }
        entries.append(
            {
                "language": target.language,
                "package": target.package,
                "registry": target.registry,
                "channel": target.channel,
                "expected_version": target.expected_version,
                "version": result.get("version", target.expected_version),
                "status": result.get("status", "ok"),
                "source": result.get("source", ""),
                "metrics": {name: result.get("metrics", {}).get(name) for name in METRIC_NAMES},
                "versions": result.get("versions", []),
                "error": result.get("error"),
                "collected_at": collected_at,
            }
        )
    return entries


def summarize(entries: Iterable[dict[str, Any]]) -> dict[str, Any]:
    languages: dict[str, dict[str, Any]] = {}
    channels: dict[str, dict[str, Any]] = {}
    for entry in entries:
        for collection, key in ((languages, entry["language"]), (channels, entry["channel"])):
            target = collection.setdefault(
                key,
                {
                    "total": 0,
                    "last_day": 0,
                    "last_week": 0,
                    "last_month": 0,
                    "packages": [],
                    "statuses": [],
                },
            )
            target["packages"].append(entry["package"])
            target["statuses"].append(entry["status"])
            for metric in METRIC_NAMES:
                value = entry["metrics"].get(metric)
                if isinstance(value, int):
                    target[metric] += value
    return {"languages": languages, "channels": channels}


def write_outputs(
    output_dir: Path,
    entries: list[dict[str, Any]],
    date: str,
    collected_at: str,
) -> dict[str, Any]:
    output_dir.mkdir(parents=True, exist_ok=True)
    snapshot = {
        "schema": SCHEMA,
        "collected_at": collected_at,
        "date": date,
        "metrics": METRIC_NAMES,
        "targets": entries,
        "summary": summarize(entries),
    }
    payload = json.dumps(snapshot, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    snapshots = output_dir / "snapshots"
    snapshots.mkdir(parents=True, exist_ok=True)
    (snapshots / f"{date}.json").write_text(payload, encoding="utf-8", newline="\n")
    (output_dir / "latest.json").write_text(payload, encoding="utf-8", newline="\n")

    series_path = output_dir / "series.csv"
    rows: list[dict[str, Any]] = []
    if series_path.is_file():
        with series_path.open(encoding="utf-8", newline="") as handle:
            rows = [row for row in csv.DictReader(handle) if row.get("date") != date]
    for entry in entries:
        for metric in METRIC_NAMES:
            value = entry["metrics"].get(metric)
            if isinstance(value, int):
                rows.append(
                    {
                        "date": date,
                        "language": entry["language"],
                        "registry": entry["registry"],
                        "channel": entry["channel"],
                        "package": entry["package"],
                        "version": entry["version"],
                        "status": entry["status"],
                        "metric": metric,
                        "value": value,
                    }
                )
    with series_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=SERIES_HEADER)
        writer.writeheader()
        writer.writerows(sorted(rows, key=lambda row: tuple(str(row[key]) for key in SERIES_HEADER)))
    (output_dir / "summary.json").write_text(
        json.dumps(snapshot["summary"], ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    (output_dir / "summary.md").write_text(summary_markdown(snapshot), encoding="utf-8", newline="\n")
    return snapshot


def summary_markdown(snapshot: dict[str, Any]) -> str:
    lines = [
        "# Registry Download Metrics",
        "",
        f"Collected: `{snapshot['collected_at']}`",
        "",
        "| Language | Registry | Version | Total | Last month | Last week | Last day | Status |",
        "| --- | --- | --- | ---: | ---: | ---: | ---: | --- |",
    ]
    for entry in snapshot["targets"]:
        metrics = entry["metrics"]
        values = [metrics.get(name) for name in ("total", "last_month", "last_week", "last_day")]
        rendered = [str(value) if isinstance(value, int) else "-" for value in values]
        lines.append(
            f"| {entry['language']} | {entry['registry']} | `{entry['version']}` | "
            + " | ".join(rendered)
            + f" | {entry['status']} |"
        )
    lines += [
        "",
        "The series is a long-form CSV keyed by date, language, registry, channel, package,",
        "version, status, metric, and value. Missing values are not zero.",
        "",
    ]
    return "\n".join(lines)


def check_outputs(output_dir: Path) -> list[str]:
    errors = []
    latest = output_dir / "latest.json"
    if not latest.is_file():
        return [f"missing {latest}"]
    try:
        snapshot = json.loads(latest.read_text(encoding="utf-8"))
    except Exception as error:
        return [f"invalid {latest}: {error}"]
    if snapshot.get("schema") != SCHEMA:
        errors.append(f"latest schema is {snapshot.get('schema')}, expected {SCHEMA}")
    if not snapshot.get("targets"):
        errors.append("latest snapshot has no targets")
    series = output_dir / "series.csv"
    if not series.is_file():
        errors.append(f"missing {series}")
    else:
        with series.open(encoding="utf-8", newline="") as handle:
            header = next(csv.reader(handle), None)
        if tuple(header or []) != SERIES_HEADER:
            errors.append(f"unexpected series header: {header}")
    return errors


def _targets_from_args(targets: list[Target], only: str | None) -> list[Target]:
    if not only:
        return targets
    allowed = {item.strip().lower() for item in only.split(",") if item.strip()}
    selected = [
        target
        for target in targets
        if target.language.lower() in allowed or target.channel.lower() in allowed
    ]
    if not selected:
        raise SystemExit(f"no targets matched --only={only}")
    return selected


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--metadata", type=Path, default=METADATA)
    parser.add_argument("--date", help="snapshot date (YYYY-MM-DD); default: UTC today")
    parser.add_argument("--only", help="comma-separated languages or channels")
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument("--user-agent", default=USER_AGENT)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--report", action="store_true")
    args = parser.parse_args(argv)

    if args.check:
        errors = check_outputs(args.output_dir)
        for error in errors:
            print(error, file=sys.stderr)
        print("registry metrics check ok" if not errors else "registry metrics check failed")
        return 1 if errors else 0

    if args.report:
        latest = args.output_dir / "latest.json"
        if not latest.is_file():
            print(f"missing {latest}", file=sys.stderr)
            return 1
        print(summary_markdown(json.loads(latest.read_text(encoding="utf-8"))))
        return 0

    date = args.date or datetime.now(timezone.utc).date().isoformat()
    try:
        datetime.strptime(date, "%Y-%m-%d")
    except ValueError as error:
        parser.error(f"invalid --date: {error}")
    collected_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    targets = _targets_from_args(load_targets(args.metadata), args.only)
    entries = collect_targets(
        targets,
        lambda url: fetch_bytes(url, args.timeout, args.user_agent),
        collected_at,
    )
    if args.dry_run:
        print(json.dumps(entries, ensure_ascii=False, indent=2, sort_keys=True))
        return 0
    snapshot = write_outputs(args.output_dir, entries, date, collected_at)
    print(summary_markdown(snapshot))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
