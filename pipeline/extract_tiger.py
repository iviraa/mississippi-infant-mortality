"""Download TIGER/Line shapefiles for Mississippi (tract, county, place)."""
from __future__ import annotations

import zipfile
from pathlib import Path

from pipeline._http import download, log, write_manifest
from pipeline.config import RAW_DIR, TIGER_FILES


def unzip(zip_path: Path, dest_dir: Path) -> None:
    dest_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(dest_dir)
    log.info(f"  extracted -> {dest_dir}")


def main() -> None:
    out = RAW_DIR / "tiger"
    out.mkdir(parents=True, exist_ok=True)
    files: list[Path] = []
    for layer, url in TIGER_FILES.items():
        zp = out / f"{layer}.zip"
        download(url, zp)
        files.append(zp)
        unzip(zp, out / layer)
    write_manifest("tiger", files, notes="TIGER 2023: MS tracts, US counties, MS places")


if __name__ == "__main__":
    main()
