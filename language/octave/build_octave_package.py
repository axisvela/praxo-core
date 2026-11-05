from __future__ import annotations

import hashlib
import re
import shutil
import tarfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent
CORE = ROOT.parent / "matlab-octave-core"
BUILD = ROOT / "build" / "octave"
VERSION = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
DESCRIPTION = ROOT / "DESCRIPTION"
PACKAGE = f"praxo-core-{VERSION}"
ARCHIVE = BUILD / f"{PACKAGE}.tar.gz"


def main() -> None:
    text = DESCRIPTION.read_text(encoding="utf-8")
    declared = re.search(r"^version:\s*(\S+)\s*$", text, re.MULTILINE)
    if not declared or declared.group(1) != VERSION:
        raise SystemExit("DESCRIPTION version does not match VERSION")

    stage = BUILD / PACKAGE
    if stage.exists():
        shutil.rmtree(stage)
    (stage / "inst").mkdir(parents=True)

    shutil.copy2(DESCRIPTION, stage / "DESCRIPTION")
    shutil.copy2(ROOT / "LICENSE", stage / "LICENSE")
    shutil.copy2(ROOT / "OCTAVE-README.md", stage / "README.md")
    shutil.copytree(CORE / "+praxo", stage / "inst" / "+praxo")

    if ARCHIVE.exists():
        ARCHIVE.unlink()
    with tarfile.open(ARCHIVE, "w:gz") as archive:
        archive.add(stage, arcname=PACKAGE, filter=lambda info: _filter(info))

    content = ARCHIVE.read_bytes()
    digest = hashlib.sha256(content).hexdigest()
    print(f"package={PACKAGE}")
    print(f"archive={ARCHIVE}")
    print(f"size={len(content)}")
    print(f"sha256={digest}")


def _filter(info: tarfile.TarInfo) -> tarfile.TarInfo:
    info.uid = 0
    info.gid = 0
    info.uname = ""
    info.gname = ""
    return info


if __name__ == "__main__":
    main()
