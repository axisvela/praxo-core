from __future__ import annotations

import hashlib
import json
import re
import shutil
import zipfile
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parent
BUILD = ROOT / "build" / "opm"
STAGE = BUILD / "PRAXO-CORE"
ZIP_NAME = "PRAXO-CORE.zip"
PACKAGE_NAME = "PRAXO-CORE"


def package_version() -> str:
    source = (ROOT / "praxo.pas").read_text(encoding="utf-8")
    match = re.search(r"PraxoSdkVersion\s*=\s*'([^']+)'", source)
    if not match:
        raise SystemExit("PraxoSdkVersion not found")
    return match.group(1)


def main() -> None:
    version = package_version()
    full_version = f"{version}.0"
    if STAGE.exists():
        shutil.rmtree(STAGE)
    STAGE.mkdir(parents=True)

    for name in ("praxo.pas", "praxo_core.pas", "praxo_agent.pas", "praxo_core.lpk"):
        shutil.copy2(ROOT / name, STAGE / name)
    shutil.copy2(ROOT / "README.md", STAGE / "README.md")
    shutil.copy2(ROOT / "LICENSE", STAGE / "LICENSE")
    api = ROOT / "api" / f"{version}.txt"
    if api.is_file():
        target = STAGE / "api"
        target.mkdir()
        shutil.copy2(api, target / api.name)

    zip_path = BUILD / ZIP_NAME
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(STAGE.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(BUILD).as_posix())

    content = zip_path.read_bytes()
    digest = hashlib.md5(content).hexdigest()
    tdatetime = (date.today() - date(1899, 12, 30)).days
    package = {
        "PackageData0": {
            "Name": PACKAGE_NAME,
            "DisplayName": PACKAGE_NAME,
            "Category": "Other",
            "CommunityDescription": (
                "Embeddable MIT agent framework Core for Free Pascal/Lazarus: "
                "tools, policy, events, memory, checkpoints, context, middleware, "
                "and a native agent loop. No Go runtime or provider adapter."
            ),
            "ExternalDependecies": "",
            "OrphanedPackage": 0,
            "RepositoryFileName": ZIP_NAME,
            "RepositoryFileSize": len(content),
            "RepositoryFileHash": digest,
            "RepositoryDate": tdatetime,
            "PackageBaseDir": f"{PACKAGE_NAME}\\/",
            "HomePageURL": "https://axisvela.github.io/praxo-core/languages/delphi/",
            "DownloadURL": "",
            "SVNURL": "",
        },
        "PackageFiles0": [
            {
                "Name": "praxo_core.lpk",
                "Description": (
                    "PRAXO-CORE native Free Pascal/Delphi Core with JSON, tool "
                    "calls, JSON Schema subset, plugin manifests, policy, memory, "
                    "checkpoints, context, middleware, events, and an agent loop."
                ),
                "Author": "AxisVela",
                "License": "MIT",
                "RelativeFilePath": "",
                "VersionAsString": full_version,
                "LazCompatibility": (
                    "Trunk, 4.8.0, 4.6.0, 4.4.0, 4.2.0, 4.0.0, 3.8.0, "
                    "3.6.0, 3.4.0, 3.2.0"
                ),
                "FPCCompatibility": "3.2.2, 3.2.0",
                "SupportedWidgetSet": "win32/win64, gtk2, qt5, qt6",
                "PackageType": 3,
                "DependenciesAsString": "FCL",
            }
        ],
    }
    json_path = BUILD / "PRAXO-CORE.json"
    json_path.write_text(json.dumps(package, indent=2), encoding="utf-8", newline="\n")
    print(f"version={version}")
    print(f"zip={zip_path} size={len(content)} md5={digest}")
    print(f"json={json_path}")


if __name__ == "__main__":
    main()
